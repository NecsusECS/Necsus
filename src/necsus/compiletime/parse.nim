import macros, sequtils, componentDef, directive

type
    SystemArgKind* {.pure.} = enum Spawn, Query, Attach, TimeDelta, Delete
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

proc spawn*(arg: SystemArg): auto = arg.spawn

proc query*(arg: SystemArg): auto = arg.query

proc attach*(arg: SystemArg): auto = arg.attach

proc parseArgKind(symbol: NimNode): SystemArgKind =
    ## Parses a type symbol to a SystemArgKind
    symbol.expectKind(nnkSym)
    case symbol.strVal
    of "Query": return SystemArgKind.Query
    of "Spawn": return SystemArgKind.Spawn
    of "Attach": return SystemArgKind.Attach
    of "TimeDelta": return SystemArgKind.TimeDelta
    of "Delete": return SystemArgKind.Delete
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

proc parseTupleSystemArg(directiveSymbol: NimNode, directiveTuple: NimNode): SystemArg =
    ## Parses a system arg given a specific symbol and tuple
    result.kind = directiveSymbol.parseArgKind
    case result.kind
    of SystemArgKind.Spawn:
        result.spawn = newSpawnDef(directiveTuple.parseDirectiveArgsFromTuple)
    of SystemArgKind.Query:
        result.query = newQueryDef(directiveTuple.parseDirectiveArgsFromTuple)
    of SystemArgKind.Attach:
        result.attach = newAttachDef(directiveTuple.parseDirectiveArgsFromTuple)
    of SystemArgKind.TimeDelta, SystemArgKind.Delete:
        error("System argument does not support tuple parameters: " & $result.kind)

proc parseFlagSystemArg(directiveSymbol: NimNode): SystemArg =
    ## Parses unparameterized system args
    result.kind = directiveSymbol.parseArgKind
    case result.kind
    of SystemArgKind.Spawn, SystemArgKind.Query, SystemArgKind.Attach:
        error("System argument is not flag based: " & $result.kind)
    of SystemArgKind.TimeDelta, SystemArgKind.Delete:
        discard

proc parseSystemArg(identDef: NimNode): SystemArg =
    ## Parses a SystemArg from a proc argument
    identDef.expectKind(nnkIdentDefs)
    let argType = identDef[1]

    case argType.kind
    of nnkBracketExpr:
        result = parseTupleSystemArg(argType[0], argType[1])
    of nnkCall:
        identDef[0].expectKind(nnkSym)
        result = parseTupleSystemArg(argType[1], argType[2])
    of nnkSym:
        result = parseFlagSystemArg(argType)
    else:
        error("Expecting an ECS interface type, but got: " & argType.repr, argType)

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
            of SystemArgKind.TimeDelta, SystemArgKind.Delete:
                discard

iterator args*(system: ParsedSystem): SystemArg =
    ## Yields all args in a system
    for arg in system.args: yield arg

iterator args*(systems: openarray[ParsedSystem]): SystemArg =
    ## Yields all args in a system
    for system in systems:
        for arg in system.args:
            yield arg

iterator queries*(systems: openarray[ParsedSystem]): QueryDef =
    ## Pulls all queries from the given parsed systems
    for arg in systems.args.toSeq.filterIt(it.kind == SystemArgKind.Query): yield arg.query

iterator spawns*(systems: openarray[ParsedSystem]): SpawnDef =
    ## Pulls all spawns from the given parsed systems
    for arg in systems.args.toSeq.filterIt(it.kind == SystemArgKind.Spawn): yield arg.spawn

iterator attaches*(systems: openarray[ParsedSystem]): AttachDef =
    ## Pulls all spawns from the given parsed systems
    for arg in systems.args.toSeq.filterIt(it.kind == SystemArgKind.Attach): yield arg.attach
