import std/[macros, sequtils, strformat, options, strutils, macrocache]
import componentDef, tupleDirective, monoDirective, dualDirective, systemGen, directiveArg
import ../runtime/[pragmas, directives], ../util/typeReader
import spawnGen, queryGen, deleteGen, attachDetachGen, sharedGen, tickIdGen
import localGen, lookupGen, eventGen, timeGen, debugGen, bundleGen, saveGen, restoreGen

type
    SystemPhase* = enum
        ## When a system should be executed
        StartupPhase,
        LoopPhase,
        TeardownPhase,
        SaveCallback,
        RestoreCallback,
        EventCallback,
        IndirectEventCallback

    ActiveCheck* = ref object
        ## A check that needs to be made before executing a system as part of the loop phase
        value*: NimNode
        arg*: SystemArg

    ParsedSystem* = ref object
        ## Parsed information about a system proc
        id*: int
        phase*: SystemPhase
        symbol*: NimNode
        prefixArgs*: seq[NimNode]
        args*: seq[SystemArg]
        depends: seq[NimNode]
        instanced*: Option[NimNode]
        checks*: seq[ActiveCheck]
        returns*: NimNode

    ParsedApp* = ref object
        ## Parsed information about the application proc itself
        name*: string
        runnerArgs*: seq[SystemArg]
        inputs*: AppInputs
        returns*: Option[MonoDirective]

proc `$`*(check: ActiveCheck): string =
    &"ActiveCheck({check.value}, {check.arg})"

proc `$`*(system: ParsedSystem): string =
    let args = join(system.args, ", ")
    let instancedStr = if system.instanced.isSome: system.instanced.get.lispRepr else: "none"
    &"{system.symbol}(" & join([
        $system.phase,
        &"args: {args}",
        &"depends: {system.depends}",
        &"instanced: {instancedStr}",
        &"checks: {system.checks}",
    ], ", ") & ")"

proc kind*(arg: SystemArg): auto = arg.kind

iterator allArgs*(system: ParsedSystem): SystemArg =
    ## Yields all args in a system
    for arg in system.args.allArgs:
        yield arg

    # Yield all arguments mentioned in the active system checks
    for check in system.checks:
        yield check.arg

proc parseArgKind(symbol: NimNode): Option[DirectiveGen] =
    ## Parses a type symbol to a SystemArgKind
    symbol.expectKind({ nnkSym, nnkIdent })
    case symbol.strVal
    of "Spawn": return some(spawnGenerator)
    of "FullSpawn": return some(fullSpawnGenerator)
    of "Query": return some(queryGenerator)
    of "FullQuery": return some(fullQueryGenerator)
    of "Attach": return some(attachGenerator)
    of "Detach": return some(detachGenerator)
    of "Shared": return some(sharedGenerator)
    of "Local": return some(localGenerator)
    of "Lookup": return some(lookupGenerator)
    of "Inbox": return some(inboxGenerator)
    of "Outbox": return some(outboxGenerator)
    of "TimeDelta": return some(deltaGenerator)
    of "TimeElapsed": return some(elapsedGenerator)
    of "EntityDebug": return some(entityDebugGenerator)
    of "Bundle": return some(bundleGenerator)
    of "Delete": return some(deleteGenerator)
    of "DeleteAll": return some(deleteAllGenerator)
    of "TickId": return some(tickIdGenerator)
    of "Save": return some(saveGenerator)
    of "Restore": return some(restoreGenerator)
    of "Swap": return some(swapGenerator)
    else: return none(DirectiveGen)

proc parseDirectiveArg(symbol: NimNode, isPointer: bool = false, kind: DirectiveArgKind = Include): DirectiveArg =
    case symbol.kind
    of nnkSym, nnkTupleTy:
        return newDirectiveArg(newComponentDef(symbol), isPointer, kind)
    of nnkBracketExpr:
        case symbol[0].strVal
        of "Not":
            return parseDirectiveArg(symbol[1], isPointer, Exclude)
        of "Option":
            return parseDirectiveArg(symbol[1], isPointer, Optional)
        else:
            return newDirectiveArg(newComponentDef(symbol), isPointer, kind)
    of nnkIdentDefs:
        return parseDirectiveArg(symbol[1], isPointer, kind)
    of nnkPtrTy:
        return parseDirectiveArg(symbol[0], true, kind)
    of nnkCall:
        if symbol[0].kind == nnkOpenSymChoice and symbol[0].repr == "[]":
            return parseDirectiveArg(nnkBracketExpr.newTree(symbol[1..^1]), isPointer, kind)
    else:
        discard
    error(&"Unexpected directive kind ({symbol.kind}): {symbol.repr}", symbol)

proc parseDirectiveArgsFromTuple(tupleArg: NimNode): seq[DirectiveArg] =
    ## Parses the symbols out of a tuple definition
    case tupleArg.kind:
    of nnkTupleConstr, nnkTupleTy:
        var output: seq[DirectiveArg]
        for child in tupleArg.children:
            output.add(parseDirectiveArg(child, false))
        return output
    of nnkSym:
        return parseDirectiveArgsFromTuple(tupleArg.getImpl)
    of nnkTypeDef:
        return parseDirectiveArgsFromTuple(tupleArg[2])
    of nnkBracketExpr:
        let resolved = tupleArg.resolveTo({ nnkTupleConstr, nnkTupleTy, nnkSym, nnkTypeDef })
        if resolved.isSome:
            return parseDirectiveArgsFromTuple(resolved.get)
    else:
        discard
    error(&"Unexpected directive argument tuple: {tupleArg.repr}", tupleArg)

template orElse[T](optional: Option[T], exec: untyped): T =
    if optional.isSome: optional.get else: exec

proc parseArgType(context, argName, argType, original: NimNode): SystemArg

proc parseNestedArgs(nestedArgs: seq[RawNestedArg]): seq[SystemArg] =
    ## If a directive references other directives, we need to extract those
    for (context, name, argType) in nestedArgs:
        result.add parseArgType(context, name, argType, argType)

proc parseParametricArg(
    context, argName, directiveSymbol: NimNode;
    directiveParametrics: openarray[NimNode]
): Option[SystemArg] =
    ## Parses a system arg given a specific symbol and tuple
    let gen = parseArgKind(directiveSymbol).orElse: return none(SystemArg)

    case gen.kind
    of DirectiveKind.Tuple:
        let tupleDir = newTupleDir(directiveParametrics[0].parseDirectiveArgsFromTuple)
        let nestedArgs = gen.nestedArgsTuple(tupleDir)
        return some(newSystemArg[TupleDirective](
            source = directiveSymbol,
            generator = gen,
            originalName = argName.strVal,
            name = gen.chooseNameTuple(context, argName, tupleDir),
            directive = tupleDir,
            nestedArgs = parseNestedArgs(nestedArgs)
        ))
    of DirectiveKind.Mono:
        let monoDir = newMonoDir(directiveParametrics[0])
        let nestedArgs = gen.nestedArgsMono(monoDir)
        return some(newSystemArg[MonoDirective](
            source = directiveSymbol,
            generator = gen,
            originalName = argName.strVal,
            name = gen.chooseNameMono(context, argName, monoDir),
            directive = monoDir,
            nestedArgs = parseNestedArgs(nestedArgs)
        ))
    of DirectiveKind.Dual:
        let dualDir = newDualDir(
            directiveParametrics[0].parseDirectiveArgsFromTuple,
            directiveParametrics[1].parseDirectiveArgsFromTuple
        )
        let nestedArgs = gen.nestedArgsDual(dualDir)
        return some(newSystemArg[DualDirective](
            source = directiveSymbol,
            generator = gen,
            originalName = argName.strVal,
            name = gen.chooseNameDual(context, argName, dualDir),
            directive = dualDir,
            nestedArgs = parseNestedArgs(nestedArgs)
        ))
    of DirectiveKind.None:
        error("System argument does not support tuple parameters: " & $gen.kind)

proc parseFlagSystemArg(name: NimNode, directiveSymbol: NimNode): Option[SystemArg] =
    ## Parses unparameterized system args
    let gen = parseArgKind(directiveSymbol).orElse: return none(SystemArg)
    case gen.kind
    of DirectiveKind.Tuple, DirectiveKind.Mono, DirectiveKind.Dual:
        error("System argument is not flag based: " & $gen.kind)
    of DirectiveKind.None:
        return some(newSystemArg[void](directiveSymbol, gen, name.strVal, directiveSymbol.strVal))

proc parseArgType(context, argName, argType, original: NimNode): SystemArg =
    ## Parses the type of a system argument

    var parsed: Option[SystemArg]
    case argType.kind:
    of nnkBracketExpr: parsed = parseParametricArg(context, argName, argType[0], argType[1..^1])
    of nnkCall: parsed = parseParametricArg(context, argName, argType[1], argType[2..^1])
    of nnkSym: parsed = parseFlagSystemArg(argName, argType)
    of nnkVarTy: parsed = some(parseArgType(context, argName, argType[0], original))
    else: parsed = none(SystemArg)

    if parsed.isSome:
        return parsed.get

    # If we were unable to parse the argument, it may be because it's a type alias. Lets try to resolve it
    let dealias = argType.resolveAlias
    if dealias.isSome:
        return parseArgType(context, argName, dealias.get, original)

    error("Expecting an ECS interface type, but got: " & original.repr, original)

proc parseSystemArg(context, identDef: NimNode): SystemArg =
    ## Parses a SystemArg from a proc argument
    identDef.expectKind({ nnkIdentDefs, nnkExprEqExpr })
    return parseArgType(context, identDef[0], identDef[1], identDef[1])

proc readDependencies(typeNode: NimNode): seq[NimNode] =
    ## Reads the systems referenced by a pragma attached to another system
    let depends = bindSym("depends")
    for child in typeNode.findPragma:
        if child.isPragma(depends):
            findChildSyms(child[1], result)

proc newActiveCheck(context, value, typename: NimNode): ActiveCheck =
    if typename.kind != nnkSym:
        error("Unexpected system state type. Got " & typename.repr, value)

    let monoDir = newMonoDir(typename)
    let arg = newSystemArg(
        source = value,
        generator = sharedGenerator,
        originalName = typename.strVal,
        name = sharedGenerator.chooseNameMono(context, typename, monoDir),
        directive = monoDir
    )
    return ActiveCheck(value: value, arg: arg)

proc parseActiveCheck(context, state: NimNode): seq[ActiveCheck] =
    ## Parses a single ActiveCheck from a node
    case state.kind
    of nnkHiddenStdConv:
        return parseActiveCheck(context, state[1])
    of nnkBracket:
        for child in state.children:
            result.add(parseActiveCheck(context, child))
    of nnkCurly:
        let setType = state.getTypeInst
        setType.expectKind(nnkBracketExpr)
        let typename = setType[1]
        for value in state.children:
            result.add(newActiveCheck(context, value, typename))
    else:
        state.expectKind(nnkSym)
        let typename = state.getTypeInst
        if typename.kind != nnkSym:
            error("Unexpected system state type. Expecting a symbol, but got " & typename.repr, state)
        return @[ newActiveCheck(context, state, typename) ]

proc parseActiveChecks(context, typeNode: NimNode): seq[ActiveCheck] =
    ## Parses any checks that need to be performed before executing a system
    let activePragma = bindSym("active")

    for child in typeNode.findPragma:
        if child.isPragma(activePragma):
            for activeState in parseActiveCheck(context, child[1]):
                result.add(activeState)

proc choosePhase(typeNode: NimNode): SystemPhase =
    ## Reads the systems referenced by a pragma attached to another system

    let startupPragma = bindSym("startupSys")
    let loopSysPragma = bindSym("loopSys")
    let teardownSysPragma = bindSym("teardownSys")
    let saveSysPragma = bindSym("saveSys")
    let restoreSysPragma = bindSym("restoreSys")
    let eventSysPragma = bindSym("eventSys")

    for child in typeNode.findPragma:
        if child.kind == nnkSym:
            if child.isPragma(startupPragma):
                return StartupPhase
            elif child.isPragma(loopSysPragma):
                return LoopPhase
            elif child.isPragma(teardownSysPragma):
                return TeardownPhase
            elif child.isPragma(saveSysPragma):
                return SaveCallback
            elif child.isPragma(restoreSysPragma):
                return RestoreCallback
            elif child.isPragma(eventSysPragma):
                return EventCallback
    return LoopPhase

proc hasInstancedReturnType(node: NimNode): bool =
    ## Returns whether the return type of a type definition declare itself as instanced
    case node.kind
    of nnkSym: return
        node == bindSym("SystemInstance") or
            node == bindSym("EventSystemInstance") or
            node == bindSym("SaveSystemInstance")
    of nnkBracketExpr: return node[0].hasInstancedReturnType
    of nnkProcTy: return node.params[0].hasInstancedReturnType
    of nnkProcDef: return node[0].getTypeImpl.hasInstancedReturnType
    of nnkIdentDefs, nnkPragmaExpr: return node[0].findSym.getTypeImpl.hasInstancedReturnType
    else: return false

proc determineInstancing(nodeImpl: NimNode, nodeTypeImpl: NimNode): Option[NimNode] =
    ## Determines whether a system is instanced, and returns the type to use for instancing
    if nodeImpl.hasInstancedReturnType():
        let tupleTy = nodeTypeImpl.params[0].resolveTo({ nnkProcTy }).get(nodeTypeImpl.params[0])
        return some(tupleTy)

    let instanced = bindSym("instanced")
    for child in nodeImpl.findPragma:
        if child.isPragma(instanced):
            return some(nodeTypeImpl[0][0])

proc getSystemType(ident: NimNode, impl: NimNode): NimNode =
    ## Returns the type definition of a system
    case impl.kind
    of nnkIdentDefs, nnkProcDef:
        return impl[1].resolveTo({ nnkProcTy }).orElse: ident.getTypeImpl
    of nnkLambda:
        return impl
    else:
        return ident.getTypeImpl

proc getPrefixArgs(
    system: NimNode,
    phase: SystemPhase,
    args: var seq[NimNode],
    instancing: Option[NimNode]
): seq[NimNode] =
    case phase
    of RestoreCallback, EventCallback, IndirectEventCallback:
        if instancing.isNone:
            if args.len <= 0:
                error("Expecting at least one parameter for system", system)
            else:
                result = @[ args[0] ]
                args = args[1..^1]
        else:
            instancing.get.expectKind(nnkProcTy)
            result = @[ instancing.get.params[1] ]
    of StartupPhase, LoopPhase, TeardownPhase, SaveCallback:
        discard

proc determineReturnType(sysTyp: NimNode, isInstanced: bool): NimNode =
    case sysTyp.kind
    of nnkBracketExpr:
        return sysTyp.resolveBracketGeneric().determineReturnType(isInstanced)
    of nnkSym:
        let impl = sysTyp.getTypeImpl

        if impl.kind == nnkSym and impl.signatureHash == sysTyp.signatureHash:
            error("Self referencing type detected: " & sysTyp.lispRepr, sysTyp)

        if impl.kind == nnkObjectTy:
            return if isInstanced: newEmptyNode() else: sysTyp
        else:
            return determineReturnType(impl, isInstanced)
    of nnkProcTy, nnkLambda:
        let typ = sysTyp.params[0]
        return if isInstanced: determineReturnType(typ, false) else: typ
    else:
        sysTyp.expectKind({ nnkProcTy, nnkSym, nnkObjectTy, nnkBracketExpr })

proc hasReturnValue(system: ParsedSystem): bool =
    ## Returns whether a return value is present for a system
    let returnNode: NimNode =
        if system.instanced.isSome:
            let instance = system.instanced.get
            if instance.typeKind == ntyObject:
                return false
            instance[0][0]
        else:
            system.returns

    return returnNode.typeKind notin { ntyNone, ntyVoid }

const systemId = CacheCounter("NecsusSystemIds")

proc parseSystemDef*(ident: NimNode, impl: NimNode): ParsedSystem =
    ## Parses a single system proc
    ident.expectKind(nnkSym)

    let typeImpl = ident.getSystemType(impl)

    # If we are given a proc, read the args directly from the proc. Otherwise, we need to
    # read them from the type, which is possibly less accurate
    let argSource = case impl.kind
        of nnkProcDef, nnkLambda: impl.params
        else: typeImpl[0]

    var args = argSource.toSeq.filterIt(it.kind == nnkIdentDefs)
    let phase = impl.choosePhase()
    let instancing = determineInstancing(impl, typeImpl)
    let prefixArgs = impl.getPrefixArgs(phase, args, instancing)

    result = ParsedSystem(
        id: systemId.value,
        phase: phase,
        symbol: ident,
        prefixArgs: prefixArgs,
        args: args.mapIt(parseSystemArg(ident, it)),
        depends: impl.readDependencies(),
        instanced: instancing,
        checks: parseActiveChecks(ident, impl),
        returns: determineReturnType(typeImpl, instancing.isSome)
    )

    systemId.inc

    # For event callbacks, if the system invokes any Outboxes, we need to break any infinite loop
    # cycles, so we flip it to an IndirectEventCallback instead
    if result.phase == EventCallback:
        for arg in result.allArgs:
            if arg.generator == outboxGenerator:
                result.phase = IndirectEventCallback
                break

    if phase == RestoreCallback and instancing.isSome:
        error("Restore callbacks do not support instancing", ident)

    if phase != SaveCallback and result.hasReturnValue:
        error("System should not return a value", result.returns)
    elif phase == SaveCallback and not result.hasReturnValue:
        error("System should must return a value", ident)

proc parseSystem(ident: NimNode): ParsedSystem =
    ## Parses a single system proc
    ident.expectKind(nnkSym)
    return parseSystemDef(ident, ident.getImpl)

proc parseSystems(systems: NimNode, into: var seq[ParsedSystem]) =
    # Recursively collects a list of systems
    case systems.kind
    of nnkSym:
        let parsed = parseSystem(systems)
        var alreadyParsed: bool
        for sys in into:
            alreadyParsed = alreadyParsed or (sys.symbol == parsed.symbol)
        if not alreadyParsed:
            for depends in parsed.depends:
                parseSystems(depends, into)
            into.add(parsed)
    of nnkPrefix:
        parseSystems(systems[1], into)
    of nnkBracket:
        for wrapped in systems.children:
            parseSystems(wrapped, into)
    else:
        systems.expectKind({nnkBracket, nnkPrefix, nnkSym})

proc parseSystemList*(systems: NimNode): seq[ParsedSystem] =
    # Parses an list of system procs into a digesteable format
    systems.expectKind(nnkBracket)
    parseSystems(systems, result)

iterator components*(arg: SystemArg): ComponentDef =
    ## Pulls all components out of an argument
    case arg.kind
    of DirectiveKind.Tuple:
        for component in arg.tupleDir: yield component
    of DirectiveKind.Dual:
        for component in arg.dualDir: yield component
    of DirectiveKind.Mono, DirectiveKind.None:
        discard

iterator components*(systems: openarray[ParsedSystem]): ComponentDef =
    ## Pulls all components from a list of parsed systems
    for system in systems:
        for arg in system.args:
            for component in arg.components:
                yield component

iterator args*(systems: openarray[ParsedSystem]): SystemArg =
    ## Yields all args in a system
    for system in systems:
        for arg in system.allArgs:
            yield arg

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

    result = impl.params.toSeq[1..^2].mapIt(parseSystemArg(runner, it))

proc parseApp*(appProc: NimNode, runner: NimNode): ParsedApp =
    ## Parses the app proc
    let returnNode = appProc.params[0]

    result = ParsedApp(
        name: appProc.name.strVal,
        inputs: @[],
        runnerArgs: parseRunner(runner),
        returns: if returnNode.kind == nnkEmpty: none(MonoDirective) else: some(newMonoDir(returnNode))
    )

    for param in appProc.params[1..^1]:
        case param.kind
        of nnkEmpty: discard
        of nnkIdentDefs:
            param[0].expectKind(nnkIdent)
            param[1].expectKind(nnkIdent)
            result.inputs.add((param[0].strVal, newMonoDir(param[1])))
        else: param.expectKind({nnkEmpty, nnkIdentDefs})


proc newEmptyApp*(name: string): ParsedApp =
    ## Creates an empty parsed app
    ParsedApp(name: name)

proc instancedInfo*(system: ParsedSystem): Option[tuple[fieldName: NimNode, typ: NimNode]] =
    ## Returns details about the instancing configuration for a type
    return if system.instanced.isSome:
        some((ident("instance_" & system.symbol.strVal), system.instanced.get))
    else:
        none(tuple[fieldName: NimNode, typ: NimNode])

proc callbackSysMailboxName*(system: ParsedSystem): NimNode =
    ## The name of the mailbox to use for an event callback system
    ident("event_mailbox_" & $system.id)

proc callbackSysType*(system: ParsedSystem): NimNode =
    ## Returns the event type handled by a callback system
    system.prefixArgs[0][1]
