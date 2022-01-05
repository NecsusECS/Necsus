import macros, sequtils, strutils

type
    SystemArgKind* {.pure.} = enum Spawn, Query
        ## The kind of arg within a system proc

    SystemArg* = object
        ## A single arg within a system proc
        case kind: SystemArgKind
        of SystemArgKind.Spawn, SystemArgKind.Query:
            components: seq[NimNode]

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

proc parseComponentsFromTuple(tupleArg: NimNode): seq[NimNode] =
    ## Parses the symbols out of a tuple definition
    tupleArg.expectKind(nnkTupleConstr)
    for child in tupleArg.children:
        child.expectKind(nnkSym)
        result.add(child)

proc parseSystemArg(ident: NimNode): SystemArg =
    ## Parses a SystemArg from a proc argument
    ident.expectKind(nnkIdentDefs)
    let argType = ident[1]

    case argType.kind
    of nnkBracketExpr:
        result.kind = argType[0].parseArgKind
        result.components = argType[1].parseComponentsFromTuple
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
