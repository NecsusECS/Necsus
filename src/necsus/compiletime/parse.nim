import macros, sequtils, componentDef, tupleDirective, localDef, monoDirective

type
    SystemArgKind* {.pure.} = enum Spawn, Query, Attach, Detach, TimeDelta, Delete, Local, Shared
        ## The kind of arg within a system proc

    SystemArg* = object
        ## A single arg within a system proc
        case kind: SystemArgKind
        of SystemArgKind.Spawn:
            spawn: SpawnDef
        of SystemArgKind.Query:
            query: QueryDef
        of SystemArgKind.Attach:
            attach: AttachDef
        of SystemArgKind.Detach:
            detach: DetachDef
        of SystemArgKind.Local:
            local: LocalDef
        of SystemArgKind.Shared:
            shared: SharedDef
        of SystemArgKind.TimeDelta, SystemArgKind.Delete:
            discard

    ParsedSystem* = object
        ## Parsed information about a system proc
        isStartup: bool
        symbol: string
        args: seq[SystemArg]

proc isStartup*(system: ParsedSystem): auto = system.isStartup

proc symbol*(system: ParsedSystem): auto = system.symbol

proc kind*(arg: SystemArg): auto = arg.kind

proc parseArgKind(symbol: NimNode): SystemArgKind =
    ## Parses a type symbol to a SystemArgKind
    symbol.expectKind(nnkSym)
    case symbol.strVal
    of "Query": return SystemArgKind.Query
    of "Spawn": return SystemArgKind.Spawn
    of "Attach": return SystemArgKind.Attach
    of "Detach": return SystemArgKind.Detach
    of "TimeDelta": return SystemArgKind.TimeDelta
    of "Delete": return SystemArgKind.Delete
    of "Local": return SystemArgKind.Local
    of "Shared": return SystemArgKind.Shared
    else: error("Unrecognized ECS interface type: " & symbol.repr, symbol)

proc parseDirectiveArg(symbol: NimNode, isPointer: bool = false): DirectiveArg =
    case symbol.kind
    of nnkSym: return newDirectiveArg(ComponentDef(symbol), isPointer)
    of nnkIdentDefs: return parseDirectiveArg(symbol[1], isPointer)
    of nnkPtrTy: return parseDirectiveArg(symbol[0], true)
    else: symbol.expectKind({nnkSym, nnkIdentDefs, nnkPtrTy})

proc parseDirectiveArgsFromTuple(tupleArg: NimNode): seq[DirectiveArg] =
    ## Parses the symbols out of a tuple definition
    tupleArg.expectKind({nnkTupleConstr, nnkTupleTy})
    for child in tupleArg.children:
        result.add(parseDirectiveArg(child, false))

proc parseParametricArg(argName: string, directiveSymbol: NimNode, directiveParametric: NimNode): SystemArg =
    ## Parses a system arg given a specific symbol and tuple
    result.kind = directiveSymbol.parseArgKind
    case result.kind
    of SystemArgKind.Spawn:
        result.spawn = newSpawnDef(directiveParametric.parseDirectiveArgsFromTuple)
    of SystemArgKind.Query:
        result.query = newQueryDef(directiveParametric.parseDirectiveArgsFromTuple)
    of SystemArgKind.Attach:
        result.attach = newAttachDef(directiveParametric.parseDirectiveArgsFromTuple)
    of SystemArgKind.Detach:
        result.detach = newDetachDef(directiveParametric.parseDirectiveArgsFromTuple)
    of SystemArgKind.Local:
        result.local = newLocalDef(argName, directiveParametric)
    of SystemArgKind.Shared:
        result.shared = newSharedDef(directiveParametric)
    of SystemArgKind.TimeDelta, SystemArgKind.Delete:
        error("System argument does not support tuple parameters: " & $result.kind)

proc parseFlagSystemArg(directiveSymbol: NimNode): SystemArg =
    ## Parses unparameterized system args
    result.kind = directiveSymbol.parseArgKind
    case result.kind
    of SystemArgKind.Spawn, SystemArgKind.Query, SystemArgKind.Attach, SystemArgKind.Detach,
        SystemArgKind.Local, SystemArgKind.Shared:
        error("System argument is not flag based: " & $result.kind)
    of SystemArgKind.TimeDelta, SystemArgKind.Delete:
        discard

proc parseArgType(argName: string, argType: NimNode): SystemArg =
    ## Parses the type of a system argument
    case argType.kind
    of nnkBracketExpr:
        return parseParametricArg(argName, argType[0], argType[1])
    of nnkCall:
        return parseParametricArg(argName, argType[1], argType[2])
    of nnkSym:
        return parseFlagSystemArg(argType)
    of nnkVarTy:
        return parseArgType(argName, argType[0])
    else:
        error("Expecting an ECS interface type, but got: " & argType.repr, argType)

proc parseSystemArg(identDef: NimNode): SystemArg =
    ## Parses a SystemArg from a proc argument
    identDef.expectKind(nnkIdentDefs)
    return parseArgType(identDef[0].strVal, identDef[1])

proc parseSystem(ident: NimNode, isStartup: bool): ParsedSystem =
    ## Parses a single system proc
    ident.expectKind(nnkSym)
    let args = ident.getImpl.params.toSeq
        .filterIt(it.kind == nnkIdentDefs)
        .mapIt(it.parseSystemArg)
    return ParsedSystem(isStartup: isStartup, symbol: ident.strVal, args: args)

proc parseSystemList*(list: NimNode, isStartup: bool): seq[ParsedSystem] =
    # Parses an inputted list of system procs into a digesteable format
    list.expectKind(nnkBracket)
    for wrappedArg in list.children:
        wrappedArg.expectKind(nnkPrefix)
        result.add(wrappedArg[1].parseSystem(isStartup))

iterator components*(systems: openarray[ParsedSystem]): ComponentDef =
    ## Pulls all components from a list of parsed systems
    for system in systems:
        for arg in system.args:
            case arg.kind
            of SystemArgKind.Spawn:
                for component in arg.spawn: yield component
            of SystemArgKind.Query:
                for component in arg.query: yield component
            of SystemArgKind.Attach:
                for component in arg.attach: yield component
            of SystemArgKind.Detach:
                for component in arg.detach: yield component
            of SystemArgKind.TimeDelta, SystemArgKind.Delete, SystemArgKind.Local, SystemArgKind.Shared:
                discard

iterator args*(system: ParsedSystem): SystemArg =
    ## Yields all args in a system
    for arg in system.args: yield arg

iterator args*(systems: openarray[ParsedSystem]): SystemArg =
    ## Yields all args in a system
    for system in systems:
        for arg in system.args:
            yield arg

template generateReaders(plural, propName, flagName, directiveType: untyped) =

    proc `propName`*(arg: SystemArg): auto = arg.`propName`

    iterator `plural`*(systems: openarray[ParsedSystem]): `directiveType` =
        ## Pulls all queries from the given parsed systems
        for arg in systems.args.toSeq.filterIt(it.kind == SystemArgKind.`flagName`): yield arg.`propName`

generateReaders(queries, query, Query, QueryDef)
generateReaders(attaches, attach, Attach, AttachDef)
generateReaders(detaches, detach, Detach, DetachDef)
generateReaders(spawns, spawn, Spawn, SpawnDef)
generateReaders(locals, local, Local, LocalDef)
generateReaders(shared, shared, Shared, SharedDef)
