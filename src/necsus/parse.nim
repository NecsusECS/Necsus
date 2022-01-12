import macros, sequtils, componentDef, directive

type
    SystemArgKind* {.pure.} = enum Spawn, Query
        ## The kind of arg within a system proc

    SystemArg* = object
        ## A single arg within a system proc
        case kind: SystemArgKind
        of SystemArgKind.Spawn:
            spawn: SpawnDef
        of SystemArgKind.Query:
            query: QueryDef

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

proc parseArgKind(symbol: NimNode): SystemArgKind =
    ## Parses a type symbol to a SystemArgKind
    symbol.expectKind(nnkSym)
    case symbol.strVal
    of "Query": return SystemArgKind.Query
    of "Spawn": return SystemArgKind.Spawn
    else: error("Unrecognized ECS interface type: " & symbol.repr, symbol)

proc parseComponentsFromTuple(tupleArg: NimNode): seq[ComponentDef] =
    ## Parses the symbols out of a tuple definition
    tupleArg.expectKind(nnkTupleConstr)
    for child in tupleArg.children:
        child.expectKind(nnkSym)
        result.add(ComponentDef(child))

proc parseSystemArg(ident: NimNode): SystemArg =
    ## Parses a SystemArg from a proc argument
    ident.expectKind(nnkIdentDefs)
    let argType = ident[1]

    case argType.kind
    of nnkBracketExpr:
        result.kind = argType[0].parseArgKind
        case result.kind
        of SystemArgKind.Spawn:
            result.spawn = newSpawnDef(argType[1].parseComponentsFromTuple)
        of SystemArgKind.Query:
            result.query = newQueryDef(argType[1].parseComponentsFromTuple)
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
    return list.children.toSeq.mapIt(it.parseSystem(isStartup))

iterator components*(systems: openarray[ParsedSystem]): ComponentDef =
    ## Pulls all components from a list of parsed systems
    for system in systems:
        for arg in system.args:
            case arg.kind
            of SystemArgKind.Spawn:
                for component in arg.spawn: yield component
            of SystemArgKind.Query:
                for component in arg.query: yield component

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

