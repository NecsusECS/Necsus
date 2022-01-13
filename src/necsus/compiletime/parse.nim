import macros, sequtils, componentDef, directive

type
    SystemArgKind* {.pure.} = enum Spawn, Query, Update
        ## The kind of arg within a system proc

    SystemArg* = object
        ## A single arg within a system proc
        case kind: SystemArgKind
        of SystemArgKind.Spawn:
            spawn: SpawnDef
        of SystemArgKind.Query:
            query: QueryDef
        of SystemArgKind.Update:
            update: UpdateDef

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

proc update*(arg: SystemArg): auto = arg.update

proc parseArgKind(symbol: NimNode): SystemArgKind =
    ## Parses a type symbol to a SystemArgKind
    symbol.expectKind(nnkSym)
    case symbol.strVal
    of "Query": return SystemArgKind.Query
    of "Spawn": return SystemArgKind.Spawn
    of "Update": return SystemArgKind.Update
    else: error("Unrecognized ECS interface type: " & symbol.repr, symbol)

proc parseComponentsFromTuple(tupleArg: NimNode): seq[ComponentDef] =
    ## Parses the symbols out of a tuple definition
    tupleArg.expectKind({nnkTupleConstr, nnkTupleTy})
    for child in tupleArg.children:
        child.expectKind({nnkSym, nnkIdentDefs})
        case child.kind
        of nnkSym: result.add(ComponentDef(child))
        of nnkIdentDefs: result.add(ComponentDef(child[1]))
        else: error("Unexpected node kind: " & child.treeRepr)

proc parseSystemArg(directiveSymbol: NimNode, directiveTuple: NimNode): SystemArg =
    ## Parses a system arg given a specific symbol and tuple
    result.kind = directiveSymbol.parseArgKind
    case result.kind
    of SystemArgKind.Spawn:
        result.spawn = newSpawnDef(directiveTuple.parseComponentsFromTuple)
    of SystemArgKind.Query:
        result.query = newQueryDef(directiveTuple.parseComponentsFromTuple)
    of SystemArgKind.Update:
        result.update = newUpdateDef(directiveTuple.parseComponentsFromTuple)

proc parseSystemArg(identDef: NimNode): SystemArg =
    ## Parses a SystemArg from a proc argument
    identDef.expectKind(nnkIdentDefs)
    let argType = identDef[1]

    case argType.kind
    of nnkBracketExpr:
        result = parseSystemArg(argType[0], argType[1])
    of nnkCall:
        identDef[0].expectKind(nnkSym)
        result = parseSystemArg(argType[1], argType[2])
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
            of SystemArgKind.Update:
                for component in arg.update: yield component

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

iterator updates*(systems: openarray[ParsedSystem]): UpdateDef =
    ## Pulls all spawns from the given parsed systems
    for arg in systems.args.toSeq.filterIt(it.kind == SystemArgKind.Update): yield arg.update

