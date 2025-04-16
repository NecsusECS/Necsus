import macros, sequtils, systemGen, options
import
  codeGenInfo, parse, common, tools, ../runtime/[systemVar, directives], ../util/profile

proc renderSystemArgs(
    codeGenInfo: CodeGenInfo, args: openarray[SystemArg]
): seq[NimNode] =
  ## Renders system arguments down to nim code
  args.mapIt:
    systemArg(codeGenInfo, it)

proc addActiveChecks*(
    invocation: NimNode,
    codeGenInfo: CodeGenInfo,
    checks: seq[ActiveCheck],
    phase: SystemPhase,
): NimNode =
  ## Wraps the system invocation code in the checks required
  if phase notin {LoopPhase, IndirectEventCallback, EventCallback} or checks.len == 0:
    return invocation

  var condition: NimNode = newLit(false)
  for check in checks:
    let sysVarRef = codeGenInfo.systemArg(check.arg)
    let checkAgainst = check.value
    condition = quote:
      `condition` or `sysVarRef` == `checkAgainst`

  return newIfStmt((condition, invocation))

proc wrapInProfiler(node: NimNode, i: int, codeGenInfo: CodeGenInfo): NimNode =
  ## Wraps a system invocation in a profiler call when enabled
  if not profilingEnabled():
    return node

  let profileVar = genSym(nskLet, "profile_start_time")
  return quote:
    block:
      let `profileVar` = `appStateIdent`.config.getTime()
      try:
        `node`
      finally:
        `appStateIdent`.profile[`i`].record(
          `appStateIdent`.config.getTime() - `profileVar`
        )

proc wrapInSystemLog(invoke: NimNode, system: ParsedSystem): NimNode =
  if not defined(necsusSystemTrace):
    return invoke

  let startMessage = emitLog("Starting system: " & system.symbol.strVal)
  let endMessage = emitLog("System done: " & system.symbol.strVal)
  result = quote:
    try:
      `startMessage`
      `invoke`
    finally:
      `endMessage`

  if system.phase == IndirectEventCallback:
    let mailboxName = system.callbackSysMailboxName
    result = quote:
      if `appStateIdent`.`mailboxName`.len > 0:
        `result`

proc singleInvokeSystem(
    codeGenInfo: CodeGenInfo, system: ParsedSystem, prefixArgs: openArray[NimNode]
): NimNode =
  ## Generates the code needed call a system once
  if system.instanced.isSome:
    let (fieldName, fieldType) = system.instancedInfo.unsafeGet
    let target =
      if fieldType.kind == nnkProcTy or fieldType == bindSym("SystemInstance"):
        newDotExpr(appStateIdent, fieldName)
      else:
        newDotExpr(newDotExpr(appStateIdent, fieldName), ident("tick"))
    newCall(target, prefixArgs.toSeq)
  else:
    return newCall(
      system.symbol, concat(prefixArgs.toSeq, codeGenInfo.renderSystemArgs(system.args))
    )

proc invokeSystem*(
    codeGenInfo: CodeGenInfo,
    system: ParsedSystem,
    phases: set[SystemPhase],
    prefixArgs: openArray[NimNode] = [],
): NimNode =
  ## Generates the code needed call a single system
  if system.phase notin phases:
    return newEmptyNode()
  elif system.phase == IndirectEventCallback:
    let eachEvent = genSym(nskForVar, "event")
    let mailboxName = system.callbackSysMailboxName
    let invoke = codeGenInfo.singleInvokeSystem(system, [eachEvent])
    result = quote:
      for `eachEvent` in `appStateIdent`.`mailboxName`:
        `invoke`
      `appStateIdent`.`mailboxName`.setLen(0)
  else:
    result = codeGenInfo.singleInvokeSystem(system, prefixArgs)

  result = result.wrapInProfiler(system.id, codeGenInfo).wrapInSystemLog(system)

  if system.phase != SaveCallback:
    result = newStmtList(
      result.addActiveChecks(codeGenInfo, system.checks, system.phase),
      codeGenInfo.generateForHook(system, AfterActiveCheck),
    )

proc callSystems*(codeGenInfo: CodeGenInfo, phases: set[SystemPhase]): NimNode =
  ## Generates the code for invoke a list of systems
  result = newStmtList()
  for i, system in codeGenInfo.systems:
    var invokeSystem = codeGenInfo.invokeSystem(system, phases)
    if invokeSystem.kind != nnkEmpty:
      result.add(invokeSystem)

proc createTickProc*(genInfo: CodeGenInfo): NimNode =
  ## Creates a function that executes the next tick
  let appStateType = genInfo.appStateTypeName

  let body =
    if isFastCompileMode(fastTick):
      newStmtList()
    else:
      let loopSystems = genInfo.callSystems({LoopPhase, IndirectEventCallback})

      let loopStart = genInfo.generateForHook(GenerateHook.LoopStart)
      let loopEnd = genInfo.generateForHook(GenerateHook.LoopEnd)

      let profiler =
        if profilingEnabled():
          quote:
            summarize(`appStateIdent`.profile, `appStateIdent`.`confIdent`)
        else:
          newEmptyNode()

      quote:
        `appStateIdent`.`thisTime` = `appStateIdent`.`confIdent`.getTime()
        `loopStart`
        block:
          `loopSystems`
        `loopEnd`
        `profiler`

  return quote:
    proc tick(`appStateIdent`: var `appStateType`) =
      `body`

proc createTickRunner*(genInfo: CodeGenInfo, runner: NimNode): NimNode =
  ## Creates the code required to execute a single tick within the world

  result = newStmtList()

  # Create a proc to use the `appState` in the current variable closure
  let runAppStateIdent = ident("runAppState")
  result.add(
    newProc(runAppStateIdent, body = newStmtList(newCall(ident("tick"), appStateIdent)))
  )

  # Invoke the runner, passing in any manually defined arguments
  var call = nnkCall.newTree(runner)
  for arg in genInfo.renderSystemArgs(genInfo.app.runnerArgs):
    call.add(arg)
  call.add(runAppStateIdent)

  result.add(call)

iterator instancedSystems(
    codeGenInfo: CodeGenInfo
): (NimNode, NimNode, seq[SystemArg]) =
  for i, system in codeGenInfo.systems:
    if system.instancedInfo.isSome:
      let (fieldName, _) = system.instancedInfo.unsafeGet
      yield (fieldName, system.symbol, system.args)

proc initializeSystems*(codeGenInfo: CodeGenInfo): NimNode =
  ## Invokes any system initializers that are required
  result = newStmtList()
  for (fieldName, symbol, args) in codeGenInfo.instancedSystems:
    let init = newCall(symbol, codeGenInfo.renderSystemArgs(args))
    result.add quote do:
      `appStateIdent`.`fieldName` = `init`

proc destroySystems*(codeGenInfo: CodeGenInfo): NimNode =
  ## Invokes any system destructors
  result = newStmtList()
  let destroy = ident("=destroy")
  for (fieldName, symbol, args) in codeGenInfo.instancedSystems:
    result.add quote do:
      `appStateIdent`.`fieldName`.`destroy`()
