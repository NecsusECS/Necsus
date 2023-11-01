import macros, sequtils, systemGen, options
import codeGenInfo, parse, commonVars, ../runtime/systemVar

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
    of LoopPhase:
        if fieldType.kind == nnkProcTy:
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

proc callSystems*(codeGenInfo: CodeGenInfo, phase: SystemPhase): NimNode =
    ## Generates the code for invoke a list of systems
    result = newStmtList()
    for system in codeGenInfo.systems:

        let invokeSystem =
            if system.instanced.isSome:codeGenInfo.callInstanced(system, phase)
            elif system.phase == phase: newCall(system.symbol, codeGenInfo.renderSystemArgs(system.args))
            else: newEmptyNode()

        result.add(invokeSystem.addActiveChecks(codeGenInfo, system.checks, phase))

proc createTickProc*(genInfo: CodeGenInfo): NimNode =
    ## Creates a function that executes the next tick
    let appStateType = genInfo.appStateTypeName

    let loopSystems = genInfo.callSystems(LoopPhase)

    let loopStart = genInfo.generateForHook(GenerateHook.LoopStart)
    let loopEnd = genInfo.generateForHook(GenerateHook.LoopEnd)

    return quote:
        proc tick(`appStateIdent`: var `appStateType`) =
            let `thisTime` {.used.} = `appStateIdent`.`confIdent`.getTime()
            `loopStart`
            block:
                `loopSystems`
            `loopEnd`

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
