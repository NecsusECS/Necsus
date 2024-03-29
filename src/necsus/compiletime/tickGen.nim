import macros, sequtils, systemGen, options
import codeGenInfo, parse, commonVars, ../runtime/[systemVar, directives], ../util/profile

proc renderSystemArgs(codeGenInfo: CodeGenInfo, args: openarray[SystemArg]): seq[NimNode] =
    ## Renders system arguments down to nim code
    args.mapIt: systemArg(codeGenInfo, it)

proc callInstanced(codeGenInfo: CodeGenInfo, system: ParsedSystem, phase: SystemPhase): NimNode =
    ## Generates the code for handling an instanced system in the given phase
    let (fieldName, fieldType) = system.instancedInfo.unsafeGet
    case phase
    of StartupPhase:
        let init = newCall(system.symbol, codeGenInfo.renderSystemArgs(system.args))
        return quote: `appStateIdent`.`fieldName` = `init`
    of LoopPhase, SaveCallback, RestoreCallback, EventCallback:
        if phase != system.phase:
            return newEmptyNode()
        elif fieldType.kind == nnkProcTy or fieldType == bindSym("SystemInstance"):
            return quote: `appStateIdent`.`fieldName`()
        else:
            return quote: `appStateIdent`.`fieldName`.tick()
    of TeardownPhase:
        let destroy = ident("=destroy")
        return quote: `appStateIdent`.`fieldName`.`destroy`()

proc addActiveChecks(
    invocation: NimNode,
    codeGenInfo: CodeGenInfo,
    checks: seq[ActiveCheck],
    phase: SystemPhase,
): NimNode =
    ## Wraps the system invocation code in the checks required
    if phase != LoopPhase or checks.len == 0:
        return invocation

    var condition: NimNode = newLit(false)
    for check in checks:
        let sysVarRef = codeGenInfo.systemArg(check.arg)
        let checkAgainst = check.value
        condition = quote:
            `condition` or `sysVarRef` == `checkAgainst`

    return newIfStmt((condition, invocation))

proc wrapInProfiler(codeGenInfo: CodeGenInfo, i: int, node: NimNode): NimNode =
    ## Wraps a system invocation in a profiler call when enabled
    if not profilingEnabled():
        return node

    let profileVar = ident("profile_start_time_" & $i)
    return quote do:
        let `profileVar` = `appStateIdent`.config.getTime()
        `node`
        `appStateIdent`.profile[`i`].record(`appStateIdent`.config.getTime() - `profileVar`)

proc logSystemCall(system: ParsedSystem, prefix: string): NimNode =
    if defined(necsusLog):
        let message = prefix & ": " & system.symbol.strVal
        return quote:
            `appStateIdent`.config.log(`message`)
    else:
        return newEmptyNode()

proc invokeSystem*(
    codeGenInfo: CodeGenInfo,
    system: ParsedSystem,
    phase: SystemPhase,
    prefixArgs: openArray[NimNode] = []
): NimNode =
    ## Generates the code needed call a single system
    return if system.instanced.isSome:
        codeGenInfo.callInstanced(system, phase)
    elif system.phase == phase:
        newCall(system.symbol, concat(prefixArgs.toSeq, codeGenInfo.renderSystemArgs(system.args)))
    else:
        newEmptyNode()

proc callSystems*(codeGenInfo: CodeGenInfo, phase: SystemPhase): NimNode =
    ## Generates the code for invoke a list of systems
    result = newStmtList()
    for i, system in codeGenInfo.systems:

        var invokeSystem = codeGenInfo.invokeSystem(system, phase)

        if invokeSystem.kind != nnkEmpty:
            invokeSystem = newStmtList(
                system.logSystemCall("Starting system"),
                invokeSystem,
                codeGenInfo.generateForHook(system, AfterSystem),
                system.logSystemCall("System done"),
            )

            if phase == SystemPhase.LoopPhase:
                invokeSystem = codeGenInfo.wrapInProfiler(i, invokeSystem)

            result.add(newStmtList(
                invokeSystem.addActiveChecks(codeGenInfo, system.checks, phase),
                codeGenInfo.generateForHook(system, AfterActiveCheck)
            ))

proc createTickProc*(genInfo: CodeGenInfo): NimNode =
    ## Creates a function that executes the next tick
    let appStateType = genInfo.appStateTypeName

    let loopSystems = genInfo.callSystems(LoopPhase)

    let loopStart = genInfo.generateForHook(GenerateHook.LoopStart)
    let loopEnd = genInfo.generateForHook(GenerateHook.LoopEnd)

    let profiler = if profilingEnabled():
        quote:
            summarize(`appStateIdent`.profile, `appStateIdent`.`confIdent`)
    else:
        newEmptyNode()

    return quote:
        proc tick(`appStateIdent`: var `appStateType`) =
            `appStateIdent`.`thisTime` = `appStateIdent`.`confIdent`.getTime()
            `loopStart`
            block:
                `loopSystems`
            `loopEnd`
            `profiler`

proc createTickRunner*(genInfo: CodeGenInfo, runner: NimNode): NimNode =
    ## Creates the code required to execute a single tick within the world

    result = newStmtList()

    # Create a proc to use the `appState` in the current variable closure
    let runAppStateIdent = ident("runAppState")
    result.add(newProc(runAppStateIdent, body = newStmtList(newCall(ident("tick"), appStateIdent))))

    # Invoke the runner, passing in any manually defined arguments
    var call = nnkCall.newTree(runner)
    for arg in genInfo.renderSystemArgs(genInfo.app.runnerArgs):
        call.add(arg)
    call.add(runAppStateIdent)

    result.add(call)
