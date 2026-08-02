import std/[macros, options, strformat, sequtils, strutils]
import
  tools, tupleDirective, dualDirective, common, queryGen, lookupGen, spawnGen,
  directiveArg
import archetype, componentDef, systemGen, archetypeBuilder
import ../runtime/[world, archetypeStore, directives], ../util/[bits, tools]

let entityIndex {.compileTime.} = ident("entityIndex")
let newComps {.compileTime.} = ident("newComps")
let entityId {.compileTime.} = ident("entityId")

proc attachedValue(component: ComponentDef, index: int): NimNode =
  ## Reads one component out of the tuple handed to an attach.
  nnkBracketExpr.newTree(newComps, newLit(index))

proc storeComponent(
    store, index: NimNode, component: ComponentDef, value: NimNode
): NimNode =
  ## Emits the write that puts a single component into its column
  newCall(
    nnkBracketExpr.newTree(bindSym("setComponent"), component.ident),
    store,
    component.columnId,
    index,
    value,
  )

proc setPresence(
    store, index: NimNode, component: ComponentDef, present: bool
): NimNode =
  ## Emits the write that records whether an entity has an accessory
  newCall(
    nnkBracketExpr.newTree(bindSym("setComponent"), bindSym("AccessoryFlag")),
    store,
    component.presenceColumnId,
    index,
    newLit(present),
  )

proc movePresence(
    fromStore, toStore, fromIndex, toIndex: NimNode, component: ComponentDef
): NimNode =
  ## Carries an accessory's presence flag across with the entity it belongs to
  newCall(
    nnkBracketExpr.newTree(bindSym("setComponent"), bindSym("AccessoryFlag")),
    toStore,
    component.presenceColumnId,
    toIndex,
    newCall(
      nnkBracketExpr.newTree(bindSym("takeColumn"), bindSym("AccessoryFlag")),
      fromStore,
      component.presenceColumnId,
      fromIndex,
    ),
  )

proc dropPresence(store, index: NimNode, component: ComponentDef): NimNode =
  ## Relocates an accessory's presence column once its entity has left the archetype
  newCall(
    nnkBracketExpr.newTree(bindSym("dropColumn"), bindSym("AccessoryFlag")),
    store,
    component.presenceColumnId,
    index,
  )

proc clearComponent(store, index: NimNode, component: ComponentDef): NimNode =
  ## Takes an accessory off an entity that is staying where it is: the value is destroyed
  ## in place and the flag saying it was there is cleared
  newStmtList(
    newCall(
      nnkBracketExpr.newTree(bindSym("clearColumn"), component.ident),
      store,
      component.columnId,
      index,
    ),
    setPresence(store, index, component, false),
  )

proc createArchUpdate(
    details: GenerateContext,
    title: string,
    attachComps: seq[ComponentDef],
    detachComps: seq[ComponentDef],
    optDetachComps: seq[ComponentDef],
    archetype: Archetype[ComponentDef],
): NimNode =
  ## Creates code for updating archetype information in place.

  let attachStr = attachComps.mapIt(it.readableName).join(", ")
  let detachStr = detachComps.mapIt(it.readableName).join(", ")
  let optDetachStr = optDetachComps.mapIt(it.readableName).join(", ")
  result = newStmtList(
    emitEntityTrace(
      fmt"{title} for ",
      entityId,
      fmt"; from {archetype.readableName}; ",
      fmt"attaching [{attachStr}], detaching [{detachStr}], optionally detaching [{optDetachStr}] ",
    )
  )

  let archIdent = archetype.ident
  let index = genSym(nskLet, "index")

  let store = quote:
    `appStateIdent`.`archIdent`

  result.add(
    newLetStmt(
      index, newCall(ident("uint32"), newDotExpr(entityIndex, ident("archetypeIndex")))
    )
  )

  for i, component in attachComps:
    result.add(storeComponent(store, index, component, component.attachedValue(i)))
    if component.isAccessory:
      result.add(setPresence(store, index, component, true))

  # Detaching without moving archetype is something only an accessory does, since anything
  # else leaving takes the entity to a different shape
  for component in both(detachComps, optDetachComps):
    if component in archetype:
      result.add(clearComponent(store, index, component))

proc createArchMove(
    details: GenerateContext,
    title: string,
    fromArch: Archetype[ComponentDef],
    attachComps: seq[ComponentDef],
    toArch: Archetype[ComponentDef],
): NimNode =
  ## Creates code for moving an entity from one archetype to another.

  let fromArchIdent = fromArch.ident
  let toArchIdent = toArch.ident
  let toArchId = toArch.idSymbol

  let fromIndex = genSym(nskLet, "fromIndex")
  let toIndex = genSym(nskLet, "toIndex")
  let moved = genSym(nskLet, "moved")

  # These are bound here rather than left to be resolved where this code is pasted, so that
  # a name in the app being generated can not shadow them
  let takeColumn = bindSym("takeColumn")
  let dropColumn = bindSym("dropColumn")
  let dropRow = bindSym("dropRow")

  let fromStore = quote:
    `appStateIdent`.`fromArchIdent`
  let toStore = quote:
    `appStateIdent`.`toArchIdent`

  result = newStmtList(
    emitEntityTrace(title, " ", entityId, " from ", fromArch.name, " to ", toArch.name)
  )

  # The destination row is claimed before anything is taken out of the source, so that
  # running out of room leaves the entity where it was instead of half moved
  result.add quote do:
    let `fromIndex` = uint32(`entityIndex`.archetypeIndex)
    let `toIndex` = reserve(`appStateIdent`.`toArchIdent`, `entityId`)

  for component in fromArch:
    let takeFrom = newCall(
      nnkBracketExpr.newTree(takeColumn, component.ident),
      fromStore,
      component.columnId,
      fromIndex,
    )

    # A component being attached is about to be overwritten, so the value already in the
    # source is not worth carrying across even when the destination has a column for it
    if component in toArch and component notin attachComps:
      result.add(storeComponent(toStore, toIndex, component, takeFrom))
      if component.isAccessory:
        result.add(movePresence(fromStore, toStore, fromIndex, toIndex, component))
    else:
      result.add(
        newCall(
          nnkBracketExpr.newTree(dropColumn, component.ident),
          fromStore,
          component.columnId,
          fromIndex,
        )
      )

      # Every column of the row being left behind has to be relocated, whether or not the
      # destination wanted it, or the rows the last entity left behind stop lining up
      if component.isAccessory:
        result.add(dropPresence(fromStore, fromIndex, component))

  for component in toArch:
    let index = attachComps.find(component)
    if index >= 0:
      result.add(
        storeComponent(toStore, toIndex, component, component.attachedValue(index))
      )
      if component.isAccessory:
        result.add(setPresence(toStore, toIndex, component, true))
    elif component notin fromArch:
      # Nothing on either side has a value for this, which only an accessory can manage.
      # The reserved row already reads as zero, so only the flag needs writing
      result.add(setPresence(toStore, toIndex, component, false))

  # Taking the row out of the source moves its last row down into the hole, which leaves
  # whichever entity was sitting there pointing at the wrong index. Nothing moves when the
  # row was already the last one, and that is what dropRow handing back this entity means
  result.add quote do:
    let `moved` = `dropRow`(`appStateIdent`.`fromArchIdent`, `fromIndex`)
    if `moved` != `entityId`:
      `appStateIdent`.`worldIdent`[`moved`].archetypeIndex = uint(`fromIndex`)
    `entityIndex`.archetype = `toArchId`
    `entityIndex`.archetypeIndex = uint(`toIndex`)

proc asBits(comps: varargs[seq[ComponentDef]]): Bits =
  result = Bits()
  for compSeq in comps:
    for comp in compSeq:
      result.incl(comp.uniqueId)

proc attachDetachProcBody(
    details: GenerateContext,
    title: string,
    attachComps: seq[ComponentDef],
    detachComps: seq[ComponentDef],
    optDetachComps: seq[ComponentDef],
): tuple[procBody: NimNode, convertProcs: NimNode] =
  ## Generates the logic needed to attach and detach components from an existing entity

  result.convertProcs = newStmtList()

  let toRemove = asBits(detachComps, optDetachComps)

  # Generate a cases statement to do the work for each kind of archetype
  var cases: NimNode = newEmptyNode()

  let totalDetaches = detachComps.len + optDetachComps.len

  if details.archetypes.len > 0:
    cases = nnkCaseStmt.newTree(newDotExpr(entityIndex, ident("archetype")))
    for (ofBranch, fromArch) in archetypeCases(details):
      if totalDetaches == 0 or fromArch.containsAllOf(detachComps) or
          fromArch.containsAnyOf(optDetachComps):
        let toArch = details.archetypeFor(fromArch.removeAndAdd(toRemove, attachComps))
        if toArch.isNil:
          discard
        elif fromArch != toArch:
          cases.add(
            nnkOfBranch.newTree(
              ofBranch, details.createArchMove(title, fromArch, attachComps, toArch)
            )
          )
        elif toArch.containsAllOf(attachComps):
          cases.add(
            nnkOfBranch.newTree(
              ofBranch,
              details.createArchUpdate(
                title, attachComps, detachComps, optDetachComps, toArch
              ),
            )
          )

    let errMsg = newLit(
      fmt"{title} failed. Attach: {attachComps}, Detach: {detachComps}, Optional Detach: {optDetachComps}"
    )

    # It's okay for archetype updating to fail if none of the detach branches match, but if we aren't detaching
    # then it's never okay to fail an attach
    cases.add(
      nnkElse.newTree(
        if detachComps.len == 0 and compileOption("assertions"):
          quote:
            assert(false, `errMsg`)
        else:
          quote:
            `appStateIdent`.`confIdent`.log(`errMsg`)
      )
    )

  result.procBody = quote:
    var `entityIndex` {.used.} = `appStateIdent`.`worldIdent`[`entityId`]
    if unlikely(`entityIndex` == nil):
      return
    `cases`

proc isAttachable(gen: DirectiveGen): bool =
  ## Returns whether this argument produces an entity that can be attached to
  gen == fullQueryGenerator or gen == lookupGenerator or gen == fullSpawnGenerator

proc attachArchetype(
    builder: var ArchetypeBuilder[ComponentDef],
    systemArgs: seq[SystemArg],
    dir: TupleDirective,
) =
  for arg in systemArgs.allArgs:
    if arg.generator.isAttachable:
      builder.attachable(dir.comps, arg.tupleDir.filter)

proc attachFields(name: string, dir: TupleDirective): seq[WorldField] =
  @[(name, nnkBracketExpr.newTree(bindSym("Attach"), dir.asTupleType))]

proc generateAttach(
    details: GenerateContext, arg: SystemArg, name: string, attach: TupleDirective
): NimNode =
  ## Generates the code for instantiating queries

  if isFastCompileMode(fastAttachDetach):
    return newEmptyNode()

  let attachProc = details.globalName(name)
  let componentTuple = attach.args.asTupleType

  case details.hook
  of Outside:
    let (body, convertProcs) =
      details.attachDetachProcBody("Attaching", attach.comps, @[], @[])

    let appStateTypeName = details.appStateTypeName
    when isSinkMemoryCorruptionFixed():
      return quote:
        `convertProcs`
        proc `attachProc`(
            `appStateIdent`: ptr `appStateTypeName`,
            `entityId`: EntityId,
            `newComps`: sink `componentTuple`,
        ) {.gcsafe, raises: [ValueError], nimcall, used.} =
          `body`

    else:
      return quote:
        `convertProcs`
        proc `attachProc`(
            `appStateIdent`: ptr `appStateTypeName`,
            `entityId`: EntityId,
            `newComps`: `componentTuple`,
        ) {.gcsafe, raises: [ValueError], nimcall, used.} =
          `body`

  of Standard:
    let procName = ident(name)
    when isSinkMemoryCorruptionFixed():
      return quote:
        `appStateIdent`.`procName` = proc(
            `entityId`: EntityId, `newComps`: sink `componentTuple`
        ) =
          `attachProc`(`appStatePtr`, `entityId`, `newComps`)
    else:
      return quote:
        `appStateIdent`.`procName` = proc(
            `entityId`: EntityId, `newComps`: `componentTuple`
        ) =
          `attachProc`(`appStatePtr`, `entityId`, `newComps`)
  else:
    return newEmptyNode()

let attachGenerator* {.compileTime.} = newGenerator(
  ident = "Attach",
  interest = {Standard, Outside},
  generate = generateAttach,
  archetype = attachArchetype,
  worldFields = attachFields,
)

proc splitDetachArgs(
    args: openarray[DirectiveArg]
): tuple[detach: seq[ComponentDef], optDetach: seq[ComponentDef]] =
  for arg in args:
    if arg.kind == Optional:
      result.optDetach.add(arg.component)
    else:
      result.detach.add(arg.component)

proc splitDetachForArchetype(
    args: openarray[DirectiveArg]
): tuple[detach: seq[ComponentDef], optDetach: seq[ComponentDef]] =
  ## The same split, for deciding which archetypes a detach can move between.
  ##
  ## An accessory is optional wherever it appears, so insisting one be present before the
  ## detach applies describes a rule no entity is subject to -- and it splits the graph in
  ## two to enforce it, doubling the search for every accessory a detach happens to name.
  ## Letting it ride along as optional reaches the same archetypes by one route instead
  ## of two
  for arg in args:
    if arg.kind == Optional or arg.component.isAccessory:
      result.optDetach.add(arg.component)
    else:
      result.detach.add(arg.component)

proc detachArchetype(
    builder: var ArchetypeBuilder[ComponentDef],
    systemArgs: seq[SystemArg],
    dir: TupleDirective,
) =
  let partition = dir.args.splitDetachForArchetype
  builder.detachable(partition.detach, partition.optDetach)

proc detachFields(name: string, dir: TupleDirective): seq[WorldField] =
  @[(name, nnkBracketExpr.newTree(bindSym("Detach"), dir.asTupleType))]

proc generateDetach(
    details: GenerateContext, arg: SystemArg, name: string, detach: TupleDirective
): NimNode =
  ## Generates the code for instantiating queries

  if isFastCompileMode(fastAttachDetach):
    return newEmptyNode()

  let detachProc = details.globalName(name)

  case details.hook
  of GenerateHook.Outside:
    let appStateTypeName = details.appStateTypeName
    let (detachComps, optDetachComps) = detach.args.splitDetachArgs
    let (body, convertProcs) =
      details.attachDetachProcBody("Detaching", @[], detachComps, optDetachComps)
    return quote:
      `convertProcs`
      proc `detachProc`(
          `appStateIdent`: ptr `appStateTypeName`, `entityId`: EntityId
      ) {.used, nimcall.} =
        `body`

  of GenerateHook.Standard:
    let procName = ident(name)
    return quote:
      `appStateIdent`.`procName` = proc(`entityId`: EntityId) =
        `detachProc`(`appStatePtr`, `entityId`)
  else:
    return newEmptyNode()

let detachGenerator* {.compileTime.} = newGenerator(
  ident = "Detach",
  interest = {Standard, Outside},
  generate = generateDetach,
  archetype = detachArchetype,
  worldFields = detachFields,
)

proc generateSwap(
    details: GenerateContext, arg: SystemArg, name: string, dir: DualDirective
): NimNode =
  ## Generates the code for instantiating queries

  if isFastCompileMode(fastAttachDetach):
    return newEmptyNode()

  let swapProc = details.globalName(name)
  let componentTuple = dir.first.asTupleType

  case details.hook
  of Outside:
    let (detachComps, optDetachComps) = dir.second.splitDetachArgs
    let (body, convertProcs) = details.attachDetachProcBody(
      "Swapping", dir.first.comps, detachComps, optDetachComps
    )
    let appStateTypeName = details.appStateTypeName
    return quote:
      `convertProcs`
      proc `swapProc`(
          `appStateIdent`: ptr `appStateTypeName`,
          `entityId`: EntityId,
          `newComps`: sink `componentTuple`,
      ) {.gcsafe, nimcall, used.} =
        `body`

  of Standard:
    let procName = ident(name)
    return quote:
      `appStateIdent`.`procName` = proc(
          `entityId`: EntityId, `newComps`: sink `componentTuple`
      ) =
        `swapProc`(`appStatePtr`, `entityId`, `newComps`)
  else:
    return newEmptyNode()

proc swapArchetype(
    builder: var ArchetypeBuilder[ComponentDef],
    systemArgs: seq[SystemArg],
    dir: DualDirective,
) =
  let attach = dir.first.comps
  let (detach, optDetach) = dir.second.splitDetachForArchetype
  for arg in systemArgs.allArgs:
    if arg.generator.isAttachable:
      builder.attachDetach(attach, detach, optDetach, arg.tupleDir.filter)

proc swapFields(name: string, dir: DualDirective): seq[WorldField] =
  @[
    (
      name,
      nnkBracketExpr.newTree(
        bindSym("Swap"), dir.first.asTupleType, dir.second.asTupleType
      ),
    )
  ]

let swapGenerator* {.compileTime.} = newGenerator(
  ident = "Swap",
  interest = {Outside, Standard},
  generate = generateSwap,
  archetype = swapArchetype,
  worldFields = swapFields,
)
