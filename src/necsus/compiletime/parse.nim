import macros, sequtils, strformat, options, typeReader, strutils
import componentDef, tupleDirective, monoDirective, systemGen
import ../runtime/[pragmas, directives]
import spawnGen, queryGen, deleteGen, attachDetachGen, sharedGen, tickIdGen
import localGen, lookupGen, eventGen, timeGen, debugGen, bundleGen, saveGen, restoreGen

type
    SystemPhase* = enum StartupPhase, LoopPhase, TeardownPhase, SaveCallback, RestoreCallback
        ## When a system should be executed

    ActiveCheck* = ref object
        ## A check that needs to be made before executing a system as part of the loop phase
        value*: NimNode
        arg*: SystemArg

    ParsedSystem* = ref object
        ## Parsed information about a system proc
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
    of "TickId": return some(tickIdGenerator)
    of "Save": return some(saveGenerator)
    of "Restore": return some(restoreGenerator)
    else: return none(DirectiveGen)

proc parseDirectiveArg(symbol: NimNode, isPointer: bool = false, kind: DirectiveArgKind = Include): DirectiveArg =
    case symbol.kind
    of nnkSym, nnkTupleTy: return newDirectiveArg(newComponentDef(symbol), isPointer, kind)
    of nnkBracketExpr:
        case symbol[0].strVal
        of "Not": return parseDirectiveArg(symbol[1], isPointer, Exclude)
        of "Option": return parseDirectiveArg(symbol[1], isPointer, Optional)
        else: return newDirectiveArg(newComponentDef(symbol), isPointer, kind)
    of nnkIdentDefs: return parseDirectiveArg(symbol[1], isPointer, kind)
    of nnkPtrTy: return parseDirectiveArg(symbol[0], true, kind)
    else: error(&"Unexpected directive kind ({symbol.kind}): {symbol.repr}", symbol)

proc parseDirectiveArgsFromTuple(tupleArg: NimNode): seq[DirectiveArg] =
    ## Parses the symbols out of a tuple definition
    case tupleArg.kind:
    of nnkTupleConstr, nnkTupleTy:
        for child in tupleArg.children:
            result.add(parseDirectiveArg(child, false))
    of nnkSym:
        return parseDirectiveArgsFromTuple(tupleArg.getImpl)
    of nnkTypeDef:
        return parseDirectiveArgsFromTuple(tupleArg[2])
    else:
        error(&"Unexpected directive argument tuple: {tupleArg.repr}", tupleArg)

template orElse[T](optional: Option[T], exec: untyped): T =
    if optional.isSome: optional.get else: exec

proc parseArgType(context, argName, argType, original: NimNode): SystemArg

proc parseNestedArgs(context: NimNode, nestedArgs: seq[RawNestedArg]): seq[SystemArg] =
    ## If a directive references other directives, we need to extract those
    for (name, argType) in nestedArgs:
        result.add parseArgType(context, name, argType, argType)

proc parseParametricArg(
    context,
    argName,
    directiveSymbol,
    directiveParametric: NimNode
): Option[SystemArg] =
    ## Parses a system arg given a specific symbol and tuple
    let gen = parseArgKind(directiveSymbol).orElse: return none(SystemArg)

    case gen.kind
    of DirectiveKind.Tuple:
        let tupleDir = newTupleDir(directiveParametric.parseDirectiveArgsFromTuple)
        let nestedArgs = gen.nestedArgsTuple(tupleDir)
        return some(newSystemArg[TupleDirective](
            source = directiveSymbol,
            generator = gen,
            originalName = argName.strVal,
            name = gen.chooseNameTuple(context, argName, tupleDir),
            directive = tupleDir,
            nestedArgs = parseNestedArgs(context, nestedArgs)
        ))
    of DirectiveKind.Mono:
        let monoDir = newMonoDir(directiveParametric)
        let nestedArgs = gen.nestedArgsMono(monoDir)
        return some(newSystemArg[MonoDirective](
            source = directiveSymbol,
            generator = gen,
            originalName = argName.strVal,
            name = gen.chooseNameMono(context, argName, monoDir),
            directive = monoDir,
            nestedArgs = parseNestedArgs(context, nestedArgs)
        ))
    of DirectiveKind.None:
        error("System argument does not support tuple parameters: " & $gen.kind)

proc parseFlagSystemArg(name: NimNode, directiveSymbol: NimNode): Option[SystemArg] =
    ## Parses unparameterized system args
    let gen = parseArgKind(directiveSymbol).orElse: return none(SystemArg)
    case gen.kind
    of DirectiveKind.Tuple, DirectiveKind.Mono:
        error("System argument is not flag based: " & $gen.kind)
    of DirectiveKind.None:
        return some(newSystemArg[void](directiveSymbol, gen, name.strVal, directiveSymbol.strVal))

proc parseArgType(context, argName, argType, original: NimNode): SystemArg =
    ## Parses the type of a system argument

    var parsed: Option[SystemArg]
    case argType.kind:
    of nnkBracketExpr: parsed = parseParametricArg(original, argName, argType[0], argType[1])
    of nnkCall: parsed = parseParametricArg(context, argName, argType[1], argType[2])
    of nnkSym: parsed = parseFlagSystemArg(argName, argType)
    of nnkVarTy: parsed = some(parseArgType(context, argName, argType[0], original))
    else: parsed = none(SystemArg)

    # If we were unable to parse the argument, it may be because it's a type alias. Lets try to resolve it
    if parsed.isNone:
        if argType.kind == nnkSym:
            let impl = argType.getImpl
            if impl.kind == nnkTypeDef:
                return parseArgType(context, argName, impl[2], original)
        error("Expecting an ECS interface type, but got: " & original.repr, original)
    else:
        return parsed.get

proc parseSystemArg(context, identDef: NimNode): SystemArg =
    ## Parses a SystemArg from a proc argument
    identDef.expectKind({ nnkIdentDefs, nnkExprEqExpr })
    return parseArgType(context, identDef[0], identDef[1], identDef[1])

proc readDependencies(typeNode: NimNode): seq[NimNode] =
    ## Reads the systems referenced by a pragma attached to another system
    let depends = bindSym("depends")
    for child in typeNode.findPragma:
        if child.kind == nnkCall and depends == child[0]:
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
        if child.kind == nnkCall and activePragma == child[0]:
            for activeState in parseActiveCheck(context, child[1]):
                result.add(activeState)

proc choosePhase(typeNode: NimNode): SystemPhase =
    ## Reads the systems referenced by a pragma attached to another system

    let startupPragma = bindSym("startupSys")
    let loopSysPragma = bindSym("loopSys")
    let teardownSysPragma = bindSym("teardownSys")
    let saveSysPragma = bindSym("saveSys")
    let restoreSysPragma = bindSym("restoreSys")

    for child in typeNode.findPragma:
        if child.kind == nnkSym:
            if startupPragma == child:
                return StartupPhase
            elif loopSysPragma == child:
                return LoopPhase
            elif teardownSysPragma == child:
                return TeardownPhase
            elif saveSysPragma == child:
                return SaveCallback
            elif restoreSysPragma == child:
                return RestoreCallback
    return LoopPhase

proc determineInstancing(nodeImpl: NimNode, nodeTypeImpl: NimNode): Option[NimNode] =
    ## Determines whether a system is instanced, and returns the type to use for instancing
    if nodeTypeImpl.kind == nnkProcTy and nodeTypeImpl.params[0] == bindSym("SystemInstance"):
        return some(nodeTypeImpl.params[0])

    for child in nodeImpl.findPragma:
        if child == bindSym("instanced"):
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

    let prefixArgs: seq[NimNode] = case phase
        of RestoreCallback:
            let first = args[0]
            args = args[1..^1]
            @[ first ]
        of StartupPhase, LoopPhase, TeardownPhase, SaveCallback:
            newSeq[NimNode]()

    return ParsedSystem(
        phase: phase,
        symbol: ident,
        prefixArgs: prefixArgs,
        args: args.mapIt(parseSystemArg(ident, it)),
        depends: impl.readDependencies(),
        instanced: determineInstancing(impl, typeImpl),
        checks: parseActiveChecks(ident, impl),
        returns: argSource[0]
    )

proc parseSystem(ident: NimNode): ParsedSystem =
    ## Parses a single system proc
    ident.expectKind(nnkSym)
    return parseSystemDef(ident, ident.getImpl)

proc parseSystems(systems: NimNode, into: var seq[ParsedSystem]) =
    # Recursively collects a list of systems
    case systems.kind
    of nnkSym:
        let parsed = parseSystem(systems)
        if into.allIt(it.symbol != parsed.symbol):
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
    of DirectiveKind.Mono, DirectiveKind.None:
        discard

iterator components*(systems: openarray[ParsedSystem]): ComponentDef =
    ## Pulls all components from a list of parsed systems
    for system in systems:
        for arg in system.args:
            for component in arg.components:
                yield component

iterator allArgs*(system: ParsedSystem): SystemArg =
    ## Yields all args in a system
    for arg in system.args.allArgs:
        yield arg

    # Yield all arguments mentioned in the active system checks
    for check in system.checks:
        yield check.arg

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
    result.new
    result.name = appProc.name.strVal

    result.inputs = @[]
    for param in appProc.params[1..^1]:
        case param.kind
        of nnkEmpty: discard
        of nnkIdentDefs:
            param[0].expectKind(nnkIdent)
            param[1].expectKind(nnkIdent)
            result.inputs.add((param[0].strVal, newMonoDir(param[1])))
        else: param.expectKind({nnkEmpty, nnkIdentDefs})
    result.runnerArgs = parseRunner(runner)

    let returnNode = appProc.params[0]
    result.returns = if returnNode.kind == nnkEmpty: none(MonoDirective) else: some(newMonoDir(returnNode))

proc newEmptyApp*(name: string): ParsedApp =
    ## Creates an empty parsed app
    ParsedApp(name: name)

proc instancedInfo*(system: ParsedSystem): Option[tuple[fieldName: NimNode, typ: NimNode]] =
    ## Returns details about the instancing configuration for a type
    return if system.instanced.isSome:
        some((ident("instance_" & system.symbol.strVal), system.instanced.get))
    else:
        none(tuple[fieldName: NimNode, typ: NimNode])

