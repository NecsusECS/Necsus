import std/[macros, options, tables, sequtils]
import codeGenInfo, archetype, common, systemGen, converters
import tickGen, parse, monoDirective, sendGen
import ../runtime/[world, archetypeStore, necsusConf], ../util/profile

proc fields(genInfo: CodeGenInfo): seq[(NimNode, NimNode)] =
  ## Produces a list of all fields to attach to the state object
  result.add (confIdent, bindSym("NecsusConf"))
  result.add (worldIdent, bindSym("World"))
  result.add (thisTime, bindSym("BiggestFloat"))
  result.add (startTime, bindSym("BiggestFloat"))

  for system in genInfo.systems:
    if system.phase == IndirectEventCallback:
      let typ = nnkBracketExpr.newTree(bindSym("seq"), system.callbackSysType)
      result.add (system.callbackSysMailboxName, typ)

  if not isFastCompileMode(fastFields):
    for archetype in genInfo.archetypes:
      let storageType = archetype.asStorageTuple
      let typ = nnkBracketExpr.newTree(bindSym("ArchetypeStore"), storageType)
      result.add (archetype.ident, typ)

  for (name, typ) in genInfo.worldFields:
    result.add (name.ident, typ)

proc createAppStateType*(genInfo: CodeGenInfo): NimNode =
  ## Creates a type definition that captures the state of the app
  var fields = nnkRecList.newTree()
  for (fieldName, fieldTyp) in items(genInfo.fields):
    fields.add nnkIdentDefs.newTree(fieldName, fieldTyp, newEmptyNode())

  # Add in any instanced systems
  for system in genInfo.systems:
    if system.instanced.isSome:
      let (fieldName, fieldType) = system.instancedInfo().unsafeGet
      fields.add nnkIdentDefs.newTree(fieldName, fieldType, newEmptyNode())

  if profilingEnabled():
    var maxId = 0
    for system in genInfo.systems:
      maxId = max(maxId, system.id)
    fields.add(
      nnkIdentDefs.newTree(
        ident("profile"),
        nnkBracketExpr.newTree(ident("array"), newLit(maxId + 1), bindSym("Profiler")),
        newEmptyNode(),
      )
    )

  let appType = genInfo.appStateTypeName
  let copy = ident("=copy")
  let a = ident("a")
  let b = ident("b")

  return newStmtList(
    nnkTypeSection.newTree(
      nnkTypeDef.newTree(
        genInfo.appStateTypeName,
        newEmptyNode(),
        nnkObjectTy.newTree(newEmptyNode(), newEmptyNode(), fields),
      )
    ),
    quote do:
      proc `copy`(`a`: var `appType`, `b`: `appType`) {.error.},
  )

proc createAppReturn*(genInfo: CodeGenInfo, errorLocation: NimNode): NimNode =
  ## Creates the return statement for the app
  if genInfo.app.returns.isSome:
    let returns = genInfo.app.returns.get()
    for generator, directives in genInfo.directives:
      if generator.kind == DirectiveKind.Mono:
        let genReturn = generator.systemReturn(directives, returns)
        if genReturn.isSome:
          return nnkReturnStmt.newTree(genReturn.get)
    error("No directives were able to supply a return value", errorLocation)
  return newEmptyNode()

proc createArchetypeState(genInfo: CodeGenInfo): NimNode =
  ## Creates variables for storing archetypes
  result = newStmtList()
  for archetype in genInfo.archetypes:
    let ident = archetype.ident
    let storageType = archetype.asStorageTuple
    let archetypeRef = archetype.idSymbol

    let calculatedSize = archetype.calculateSize
    let size =
      if calculatedSize.isSome:
        calculatedSize.get
      else:
        quote:
          `appStateIdent`.config.componentSize

    result.add quote do:
      `appStateIdent`.`ident` = newArchetypeStore[`storageType`](`archetypeRef`, `size`)
      if `appStateIdent`.`confIdent`.eagerAlloc:
        ensureAlloced(`appStateIdent`.`ident`)

proc initProfilers(genInfo: CodeGenInfo): NimNode =
  result = newStmtList()
  if profilingEnabled():
    for system in genInfo.systems:
      let name = system.symbol.strVal
      let i = system.id
      result.add quote do:
        `appStateIdent`.profile[`i`].name = `name`

proc buildInitChunks(
    stmts: seq[NimNode],
    appStateTypeName: NimNode,
    paramDefs: seq[NimNode],
    extraArgNames: seq[NimNode],
): NimNode =
  ## Splits a flat statement list into fixed-size {.noinline.} chunk procs.
  ## Each chunk defines its own appStatePtr so Nim ARC's colontmpD__ temporaries
  ## (one per closure-generating directive) are confined to that chunk's stack
  ## frame and freed on return, rather than accumulating across a single large frame.
  const initChunkSize = 16
  result = newStmtList()
  for i in countup(0, stmts.len - 1, initChunkSize):
    let chunkBody = newStmtList(
      quote do:
        let `appStatePtr` {.used.} = cast[ptr `appStateTypeName`](`appStateIdent`)
    )
    chunkBody.add(stmts[i ..< min(i + initChunkSize, stmts.len)])
    let chunkIdent = genSym(nskProc, "initChunk")
    result.add(
      newProc(
        name = chunkIdent,
        params =
          @[
            newEmptyNode(),
            newIdentDefs(appStateIdent, nnkRefTy.newTree(appStateTypeName)),
          ] & paramDefs,
        body = chunkBody,
        pragmas = nnkPragma.newTree(ident("noinline")),
      ),
      newCall(chunkIdent, @[appStateIdent] & extraArgNames),
    )

proc createAppStateInit*(genInfo: CodeGenInfo): NimNode =
  ## Creates a proc for initializing the app state object

  let appStateTypeName = genInfo.appStateTypeName
  let args =
    genInfo.app.inputs.mapIt(newIdentDefs(it.argName.ident, it.directive.argType))

  let initBody =
    if isFastCompileMode(fastInit):
      quote:
        result = new(`appStateTypeName`)
    else:
      let createConfig = genInfo.config
      let extraArgNames = genInfo.app.inputs.mapIt(it.argName.ident)

      var allInitWork = @[genInfo.createArchetypeState(), genInfo.initProfilers()]
      for stmt in genInfo.generateForHook(GenerateHook.Standard):
        allInitWork.add(stmt)
      allInitWork &=
        @[
          genInfo.initIndirectEventInboxes(),
          genInfo.generateForHook(GenerateHook.Late),
          genInfo.initializeSystems(),
          genInfo.callSystems({StartupPhase}),
          genInfo.generateForHook(GenerateHook.BeforeLoop),
        ]

      let chunks = buildInitChunks(allInitWork, appStateTypeName, args, extraArgNames)

      quote:
        result = new(`appStateTypeName`)
        let `appStateIdent` = result
        `appStateIdent`.`confIdent` = `createConfig`
        `appStateIdent`.`confIdent`.log("Beginning app initialization")
        `appStateIdent`.`worldIdent` = newWorld(`appStateIdent`.`confIdent`.entitySize)
        `appStateIdent`.`startTime` = `appStateIdent`.`confIdent`.getTime()
        `chunks`

  return newStmtList(
    newProc(
      name = genInfo.appStateInit,
      params = @[nnkRefTy.newTree(appStateTypeName)].concat(args),
      body = initBody,
    )
  )

proc createAppStateInstance*(genInfo: CodeGenInfo): NimNode =
  ## Creates the instance of the app state object
  let extraArgs = genInfo.app.inputs.mapIt(it.argName.ident)
  let invoke = newCall(genInfo.appStateInit, extraArgs)
  return quote:
    let `appStateIdent` = `invoke`

proc createAppStateDestructor*(genInfo: CodeGenInfo): NimNode =
  ## Creates the instance of the app state object
  let appStateType = genInfo.appStateTypeName
  let destroy = "=destroy".ident

  let destroys = newStmtList()

  if not isFastCompileMode(fastDestroy):
    destroys.add(genInfo.callSystems({TeardownPhase}))
    destroys.add(genInfo.destroySystems())

    for (name, _) in items(genInfo.fields):
      destroys.add quote do:
        `destroy`(`appStateIdent`.`name`)

  return quote:
    {.warning[Deprecated]: off, hint[XCannotRaiseY]: off.}
    proc `destroy`*(`appStateIdent`: var `appStateType`) {.raises: [Exception], used.} =
      `destroys`

proc createConverterProcs*(details: CodeGenInfo): NimNode =
  ## Creates a list of procs for converting from one tuple type to another
  result = newStmtList()

  let ctx = details.newGenerateContext(Outside)
  for arg in details.allArgs:
    for convert in converters(ctx, arg):
      result.add(buildConverter(convert))

proc createArchetypeIdSyms*(details: CodeGenInfo): NimNode =
  result = newStmtList()
  for archetype in details.archetypes:
    result.add(archetype.archArchSymbolDef)
