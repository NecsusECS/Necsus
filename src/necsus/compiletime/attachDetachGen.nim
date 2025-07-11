import std/[macros, options, strformat, sequtils, strutils]
import
  tools, tupleDirective, dualDirective, common, queryGen, lookupGen, spawnGen,
  directiveArg
import archetype, componentDef, systemGen, archetypeBuilder, converters
import ../runtime/[world, archetypeStore, directives], ../util/[bits, tools]

let entityIndex {.compileTime.} = ident("entityIndex")
let newComps {.compileTime.} = ident("newComps")
let entityId {.compileTime.} = ident("entityId")

proc createArchUpdate(
    details: GenerateContext,
    title: string,
    attachComps: seq[ComponentDef],
    detachComps: seq[ComponentDef],
    optDetachComps: seq[ComponentDef],
    archetype: Archetype[ComponentDef],
): NimNode =
  ## Creates code for updating archetype information in place

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
  let archTuple = archetype.asStorageTuple

  let existing = ident("existing")
  result.add quote do:
    let `existing` =
      getComps[`archTuple`](`appStateIdent`.`archIdent`, `entityIndex`.archetypeIndex)

  for i, component in attachComps:
    let storageIndex = archetype.indexOf(component)
    let adapter = newAdapter(archetype, attachComps, component, newComps, existing)
    let newValue = adapter.build()
    result.add quote do:
      `existing`[`storageIndex`] = `newValue`

  for component in both(detachComps, optDetachComps):
    if component in archetype:
      let storageIndex = archetype.indexOf(component)
      let typ = component.node
      result.add quote do:
        `existing`[`storageIndex`] = none[`typ`]()

proc newCompsTupleType(newCompValues: seq[ComponentDef]): NimNode =
  ## Creates the type definition to use for a tuple that represents new values passed into a convert proc
  if newCompValues.len > 0:
    return newCompValues.asTupleType
  else:
    return quote:
      (int,)

proc createArchMove(
    details: GenerateContext,
    title: string,
    fromArch: Archetype[ComponentDef],
    newCompValues: seq[ComponentDef],
    toArch: Archetype[ComponentDef],
    convert: ConverterDef,
): NimNode =
  ## Creates code for copying from one archetype to another
  let fromArchIdent = fromArch.ident
  let fromArchTuple = fromArch.asStorageTuple
  let toArchTuple = toArch.asStorageTuple
  let toArchIdent = toArch.ident
  let convertProc = convert.name
  let newCompsType = newCompValues.newCompsTupleType()

  let newCompsArg =
    if newCompValues.len > 0:
      newComps
    else:
      quote:
        (0,)

  let log =
    emitEntityTrace(title, " ", entityId, " from ", fromArch.name, " to ", toArch.name)

  return quote:
    `log`
    moveEntity[`fromArchTuple`, `newCompsType`, `toArchTuple`](
      `appStateIdent`.`worldIdent`, `entityIndex`, `appStateIdent`.`fromArchIdent`,
      `appStateIdent`.`toArchIdent`, `newCompsArg`, `convertProc`,
    )

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
          let convert = newConverter(fromArch, attachComps, toArch, true)
          result.convertProcs.add(convert.buildConverter)
          cases.add(
            nnkOfBranch.newTree(
              ofBranch,
              details.createArchMove(title, fromArch, attachComps, toArch, convert),
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

proc detachArchetype(
    builder: var ArchetypeBuilder[ComponentDef],
    systemArgs: seq[SystemArg],
    dir: TupleDirective,
) =
  let partition = dir.args.splitDetachArgs
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
  let (detach, optDetach) = dir.second.splitDetachArgs
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
