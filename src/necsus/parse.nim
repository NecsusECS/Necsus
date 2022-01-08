import macros, sequtils, componentDef, queryDef

type
    SystemArgKind* {.pure.} = enum Spawn, Query
        ## The kind of arg within a system proc

    SystemArg* = object
        ## A single arg within a system proc
        case kind: SystemArgKind
        of SystemArgKind.Spawn:
            components: seq[ComponentDef]
        of SystemArgKind.Query:
            query: QueryDef

    ParsedSystem* = object
        ## Parsed information about a system proc
        isStartup: bool
        args: seq[SystemArg]

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
            result.components = argType[1].parseComponentsFromTuple
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
    return ParsedSystem(isStartup: isStartup, args: args)

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
                for component in arg.components:
                    yield component
            of SystemArgKind.Query:
                for component in arg.query:
                    yield component

iterator queries*(systems: openarray[ParsedSystem]): QueryDef =
    ## Pulls all queries from the given parsed systems
    for system in systems:
        for arg in system.args:
            case arg.kind
            of SystemArgKind.Spawn:
                discard
            of SystemArgKind.Query:
                yield arg.query

