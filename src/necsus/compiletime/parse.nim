import macros, sequtils, componentDef, tupleDirective, localDef, monoDirective, strformat, options

type
    SystemPhase* = enum StartupPhase, LoopPhase, TeardownPhase
        ## When a system should be executed

    SystemArgKind* {.pure.} = enum
        ## The kind of arg within a system proc
        Spawn, Query, Attach, Detach, TimeDelta, TimeElapsed, Delete, Local, Shared, Lookup, Inbox, Outbox

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
        of SystemArgKind.Lookup:
            lookup: LookupDef
        of SystemArgKind.Inbox:
            inbox: InboxDef
        of SystemArgKind.Outbox:
            outbox: OutboxDef
        of SystemArgKind.TimeDelta, SystemArgKind.TimeElapsed, SystemArgKind.Delete:
            discard

    ParsedSystem* = object
        ## Parsed information about a system proc
        phase: SystemPhase
        symbol: string
        args*: seq[SystemArg]

    ParsedApp* = object
        ## Parsed information about the application proc itself
        runnerArgs*: seq[SystemArg]
        inputs*: seq[tuple[argName: string, directive: SharedDef]]
        returns*: Option[SharedDef]

proc phase*(system: ParsedSystem): auto = system.phase

proc symbol*(system: ParsedSystem): auto = system.symbol

proc kind*(arg: SystemArg): auto = arg.kind

proc parseArgKind(symbol: NimNode): Option[SystemArgKind] =
    ## Parses a type symbol to a SystemArgKind
    symbol.expectKind(nnkSym)
    case symbol.strVal
    of "Query": return some(SystemArgKind.Query)
    of "Spawn": return some(SystemArgKind.Spawn)
    of "Attach": return some(SystemArgKind.Attach)
    of "Detach": return some(SystemArgKind.Detach)
    of "TimeDelta": return some(SystemArgKind.TimeDelta)
    of "TimeElapsed": return some(SystemArgKind.TimeElapsed)
    of "Delete": return some(SystemArgKind.Delete)
    of "Local": return some(SystemArgKind.Local)
    of "Shared": return some(SystemArgKind.Shared)
    of "Lookup": return some(SystemArgKind.Lookup)
    of "Inbox": return some(SystemArgKind.Inbox)
    of "Outbox": return some(SystemArgKind.Outbox)
    else: return none(SystemArgKind)
        #error("Unrecognized ECS interface type: " & symbol.repr, symbol)

proc parseDirectiveArg(symbol: NimNode, isPointer: bool = false, kind: DirectiveArgKind = Include): DirectiveArg =
    case symbol.kind
    of nnkSym: return newDirectiveArg(ComponentDef(symbol), isPointer, kind)
    of nnkBracketExpr:
        case symbol[0].strVal
        of "Not": return parseDirectiveArg(symbol[1], isPointer, Exclude)
        of "Option": return parseDirectiveArg(symbol[1], isPointer, Optional)
        else: return newDirectiveArg(ComponentDef(symbol), isPointer, kind)
    of nnkIdentDefs: return parseDirectiveArg(symbol[1], isPointer, kind)
    of nnkPtrTy: return parseDirectiveArg(symbol[0], true, kind)
    else: error(&"Unexpected directive kind ({symbol.kind}): {symbol.repr}")

proc parseDirectiveArgsFromTuple(tupleArg: NimNode): seq[DirectiveArg] =
    ## Parses the symbols out of a tuple definition
    tupleArg.expectKind({nnkTupleConstr, nnkTupleTy})
    for child in tupleArg.children:
        result.add(parseDirectiveArg(child, false))

template orElse[T](optional: Option[T], exec: untyped): T =
    if optional.isSome: optional.get else: exec

proc parseParametricArg(argName: string, directiveSymbol: NimNode, directiveParametric: NimNode): Option[SystemArg] =
    ## Parses a system arg given a specific symbol and tuple
    let kind = directiveSymbol.parseArgKind.orElse: return none(SystemArg)

    case kind
    of SystemArgKind.Spawn:
        return some(SystemArg(kind: kind, spawn: newSpawnDef(directiveParametric.parseDirectiveArgsFromTuple)))
    of SystemArgKind.Query:
        return some(SystemArg(kind: kind, query: newQueryDef(directiveParametric.parseDirectiveArgsFromTuple)))
    of SystemArgKind.Attach:
        return some(SystemArg(kind: kind, attach: newAttachDef(directiveParametric.parseDirectiveArgsFromTuple)))
    of SystemArgKind.Detach:
        return some(SystemArg(kind: kind, detach: newDetachDef(directiveParametric.parseDirectiveArgsFromTuple)))
    of SystemArgKind.Lookup:
        return some(SystemArg(kind: kind, lookup: newLookupDef(directiveParametric.parseDirectiveArgsFromTuple)))
    of SystemArgKind.Local:
        return some(SystemArg(kind: kind, local: newLocalDef(argName, directiveParametric)))
    of SystemArgKind.Shared:
        return some(SystemArg(kind: kind, shared: newSharedDef(directiveParametric)))
    of SystemArgKind.Inbox:
        return some(SystemArg(kind: kind, inbox: newInboxDef(directiveParametric)))
    of SystemArgKind.Outbox:
        return some(SystemArg(kind: kind, outbox: newOutboxDef(directiveParametric)))
    of SystemArgKind.TimeDelta, SystemArgKind.TimeElapsed, SystemArgKind.Delete:
        error("System argument does not support tuple parameters: " & $kind)

proc parseFlagSystemArg(directiveSymbol: NimNode): Option[SystemArg] =
    ## Parses unparameterized system args
    let kind = directiveSymbol.parseArgKind.orElse: return none(SystemArg)
    case kind
    of SystemArgKind.Spawn, SystemArgKind.Query, SystemArgKind.Attach, SystemArgKind.Detach,
        SystemArgKind.Local, SystemArgKind.Shared, SystemArgKind.Lookup, SystemArgKind.Inbox, SystemArgKind.Outbox:
        error("System argument is not flag based: " & $kind)
    of SystemArgKind.TimeDelta, SystemArgKind.TimeElapsed, SystemArgKind.Delete:
        return some(SystemArg(kind: kind))

proc parseArgType(argName: string, argType, original: NimNode): SystemArg =
    ## Parses the type of a system argument

    var parsed: Option[SystemArg]
    case argType.kind:
    of nnkBracketExpr: parsed = parseParametricArg(argName, argType[0], argType[1])
    of nnkCall: parsed = parseParametricArg(argName, argType[1], argType[2])
    of nnkSym: parsed = parseFlagSystemArg(argType)
    of nnkVarTy: parsed = some(parseArgType(argName, argType[0], original))
    else: parsed = none(SystemArg)

    # If we were unable to parse the argument, it may be because it's a type alias. Lets try to resolve it
    if parsed.isNone:
        let impl = argType.getImpl
        if impl.kind == nnkTypeDef:
            return parseArgType(argName, impl[2], original)
        else:
            error("Expecting an ECS interface type, but got: " & original.repr, original)
    else:
        return parsed.get

proc parseSystemArg(identDef: NimNode): SystemArg =
    ## Parses a SystemArg from a proc argument
    identDef.expectKind(nnkIdentDefs)
    return parseArgType(identDef[0].strVal, identDef[1], identDef[1])

proc parseSystem(ident: NimNode, phase: SystemPhase): ParsedSystem =
    ## Parses a single system proc
    ident.expectKind(nnkSym)
    let args = ident.getImpl.params.toSeq
        .filterIt(it.kind == nnkIdentDefs)
        .mapIt(it.parseSystemArg)
    return ParsedSystem(phase: phase, symbol: ident.strVal, args: args)

proc parseSystemList*(list: NimNode, phase: SystemPhase): seq[ParsedSystem] =
    # Parses an inputted list of system procs into a digesteable format
    list.expectKind(nnkBracket)
    for wrappedArg in list.children:
        wrappedArg.expectKind(nnkPrefix)
        result.add(wrappedArg[1].parseSystem(phase))

iterator components*(arg: SystemArg): ComponentDef =
    ## Pulls all components out of an argument
    case arg.kind
    of SystemArgKind.Spawn:
        for component in arg.spawn: yield component
    of SystemArgKind.Query:
        for component in arg.query: yield component
    of SystemArgKind.Attach:
        for component in arg.attach: yield component
    of SystemArgKind.Detach:
        for component in arg.detach: yield component
    of SystemArgKind.Lookup:
        for component in arg.lookup: yield component
    of SystemArgKind.TimeDelta, SystemArgKind.TimeElapsed, SystemArgKind.Delete, SystemArgKind.Local,
        SystemArgKind.Shared, SystemArgKind.Inbox, SystemArgKind.Outbox:
        discard

iterator components*(systems: openarray[ParsedSystem]): ComponentDef =
    ## Pulls all components from a list of parsed systems
    for system in systems:
        for arg in system.args:
            for component in arg.components:
                yield component

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

    proc `plural`*(systems: openarray[ParsedSystem]): seq[`directiveType`] =
        ## Pulls all queries from the given parsed systems
        for arg in systems.args.toSeq.filterIt(it.kind == SystemArgKind.`flagName`): result.add(arg.`propName`)

    proc `plural`*(app: ParsedApp): seq[`directiveType`] =
        ## Pulls directives out of the app
        for arg in app.runnerArgs.filterIt(it.kind == SystemArgKind.`flagName`): result.add(arg.`propName`)
        when directiveType is SharedDef:
            for input in app.inputs: result.add(input.directive)
            if app.returns.isSome:
                result.add(app.returns.get())


generateReaders(queries, query, Query, QueryDef)
generateReaders(attaches, attach, Attach, AttachDef)
generateReaders(detaches, detach, Detach, DetachDef)
generateReaders(spawns, spawn, Spawn, SpawnDef)
generateReaders(locals, local, Local, LocalDef)
generateReaders(shared, shared, Shared, SharedDef)
generateReaders(lookups, lookup, Lookup, LookupDef)
generateReaders(inboxes, inbox, Inbox, InboxDef)
generateReaders(outboxes, outbox, Outbox, OutboxDef)

iterator components*(app: ParsedApp): ComponentDef =
    ## List all components referenced by an app
    for arg in app.runnerArgs:
        for component in arg.components:
            yield component

proc parseRunner(runner: NimNode): seq[SystemArg] =
    ## Parses the arguments of the runner
    runner.expectKind(nnkSym)
    let impl = runner.getImpl

    # Verify that the last argument is a proc
    impl.params[^1][1].expectKind(nnkProcTy)

    result = impl.params.toSeq[1..^2].mapIt(parseSystemArg(it))

proc parseApp*(appProc: NimNode, runner: NimNode): ParsedApp =
    ## Parses the app proc
    result.inputs = @[]
    for param in appProc.params[1..^1]:
        case param.kind
        of nnkEmpty: discard
        of nnkIdentDefs:
            param[0].expectKind(nnkIdent)
            param[1].expectKind(nnkIdent)
            result.inputs.add((param[0].strVal, newSharedDef(param[1])))
        else: param.expectKind({nnkEmpty, nnkIdentDefs})
    result.runnerArgs = parseRunner(runner)

    let returnNode = appProc.params[0]
    result.returns = if returnNode.kind == nnkEmpty: none(SharedDef) else: some(newSharedDef(returnNode))
