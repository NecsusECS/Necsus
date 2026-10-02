import std/[macros, options]
import
  tools, tupleDirective, archetype, archetypeBuilder, componentDef, common, systemGen,
  directiveArg
import ../runtime/[spawn, archetypeStore, world]

proc branches(dir: TupleDirective): seq[ComponentDef] =
  ## The optional components that decide which archetype a spawn lands in.
  ##
  ## An optional accessory is not one of them. An archetype holding an accessory already
  ## holds rows both with and without it, so leaving one out is a matter of the presence
  ## flag rather than of picking a different archetype
  for arg in dir.args:
    if arg.kind == Optional and not arg.isAccessory:
      result.add(arg.component)

proc always(dir: TupleDirective): seq[ComponentDef] =
  ## The components that are in the archetype whichever optional components turn up
  for arg in dir.args:
    if arg.kind != Optional or arg.isAccessory:
      result.add(arg.component)

proc archetypes(
    builder: var ArchetypeBuilder[ComponentDef],
    systemArgs: seq[SystemArg],
    dir: TupleDirective,
) =
  ## Every combination of optional components is an archetype the spawn can land in, so
  ## each one has to exist up front
  let always = dir.always
  let branches = dir.branches
  for mask in 0 ..< (1 shl branches.len):
    var comps = always
    for i, comp in branches:
      if (mask and (1 shl i)) != 0:
        comps.add(comp)
    builder.define(comps)

proc worldFields(name: string, dir: TupleDirective): seq[WorldField] =
  @[(name, nnkBracketExpr.newTree(bindSym("RawSpawn"), dir.asTupleType))]

proc systemArg(spawnType: NimNode, name: string): NimNode =
  let sysIdent = name.ident
  return quote:
    `appStateIdent`.`sysIdent`.`spawnType`

proc spawnSystemArg(name: string, dir: TupleDirective): NimNode =
  systemArg(bindSym("asSpawn"), name)

proc fullSpawnSystemArg(name: string, dir: TupleDirective): NimNode =
  systemArg(bindSym("asFullSpawn"), name)

when NimMajor >= 2:
  import std/macrocache
  const spawnSymbols = CacheTable("NecsusSpawnSymbols")
else:
  import std/tables
  var spawnSymbols {.compileTime.} = initTable[string, NimNode]()

proc spawnProcName(details: GenerateContext, dir: TupleDirective): NimNode =
  ## Returns the symbol for a spawn proc
  let sig = details.globalStr(dir.signature)
  if sig notin spawnSymbols:
    spawnSymbols[sig] = genSym(nskProc, "spawn")
  return spawnSymbols[sig]

when NimMajor >= 2:
  const spawnProcs = CacheTable("NecsusSpawnProcs")
else:
  var spawnProcs {.compileTime.} = initTable[string, NimNode]()

proc storeComponents(
    archetype: Archetype[ComponentDef],
    dir: TupleDirective,
    store, index, readFrom: NimNode,
): NimNode =
  ## Generates the writes that put a spawned tuple into an archetype.
  result = newStmtList()
  let setComponent = bindSym("setComponent")

  for component in archetype.values:
    let present = component in dir

    # Only an accessory can be missing from the tuple while the archetype still has a
    # column for it. Nothing needs writing in that case -- a reserved row reads as zero --
    # but the flag saying so does
    if not present:
      if component.isAccessory:
        result.add(
          newCall(
            nnkBracketExpr.newTree(setComponent, bindSym("AccessoryFlag")),
            store,
            component.presenceColumnId,
            index,
            newLit(false),
          )
        )
      continue

    let arg = dir.args[dir.indexOf(component)]
    let field = nnkBracketExpr.newTree(readFrom, dir.indexOf(component).newLit)
    let write = newCall(
      nnkBracketExpr.newTree(setComponent, component.ident),
      store,
      component.columnId,
      index,
      if arg.kind == Optional:
        newCall(bindSym("unsafeGet"), field)
      else:
        field,
    )

    if arg.kind == Optional and component.isAccessory:
      # Whether an optional accessory is there is only known once the value is in hand.
      # The archetype is the same either way, so it is the flag that carries the answer
      let isSome = newCall(bindSym("isSome"), field)
      let presenceId = component.presenceColumnId
      let flagType = bindSym("AccessoryFlag")
      result.add quote do:
        if `isSome`:
          `write`
          `setComponent`[`flagType`](`store`, `presenceId`, `index`, true)
        else:
          `setComponent`[`flagType`](`store`, `presenceId`, `index`, false)
    else:
      # An optional component that is not an accessory only reaches this point in the
      # archetype that was picked because it was there
      result.add(write)
      if component.isAccessory:
        result.add(
          newCall(
            nnkBracketExpr.newTree(setComponent, bindSym("AccessoryFlag")),
            store,
            component.presenceColumnId,
            index,
            newLit(true),
          )
        )

proc spawnInto(
    details: GenerateContext,
    dir: TupleDirective,
    comps: seq[ComponentDef],
    newEntity, value: NimNode,
): NimNode =
  ## Puts a spawned entity into the archetype holding exactly the given components
  let archetype = details.archetypeFor(comps)
  let archIdent = archetype.ident
  let archetypeRef = archetype.idSymbol
  let index = genSym(nskLet, "index")
  let store = quote:
    `appStateIdent`.`archIdent`
  let storeComps = archetype.storeComponents(dir, store, index, value)
  return quote:
    let `index` = reserve(`appStateIdent`.`archIdent`, result)
    `newEntity`.setArchetypeDetails(`archetypeRef`, uint(`index`))
    `storeComps`

proc chooseArchetype(
    details: GenerateContext,
    dir: TupleDirective,
    comps: seq[ComponentDef],
    branches: seq[ComponentDef],
    newEntity, value: NimNode,
): NimNode =
  ## Branches on each optional component in turn until the archetype is settled
  if branches.len == 0:
    return details.spawnInto(dir, comps, newEntity, value)

  let next = branches[0]
  let rest = branches[1 ..^ 1]
  let isSome = newCall(
    bindSym("isSome"), nnkBracketExpr.newTree(value, dir.indexOf(next).newLit)
  )
  let withIt = details.chooseArchetype(dir, comps & next, rest, newEntity, value)
  let withoutIt = details.chooseArchetype(dir, comps, rest, newEntity, value)
  return quote:
    if `isSome`:
      `withIt`
    else:
      `withoutIt`

proc buildSpawnProc(details: GenerateContext, dir: TupleDirective): NimNode =
  ## Builds the proc needed to execute a spawn against the given tuple
  let sig = details.globalStr(dir.signature)
  if sig in spawnProcs:
    return newEmptyNode()

  let appState = details.appStateTypeName
  let spawnProc = details.spawnProcName(dir)
  let value = genSym(nskParam, "value")
  let entity = genSym(nskVar, "newEntity")
  let log = emitEntityTrace("Spawned ", ident("result"), " of kind ", $dir)
  let tupleTyp = dir.asTupleType
  let storeComps =
    details.chooseArchetype(dir, dir.always, dir.branches, entity, value)

  result = quote:
    proc `spawnProc`(
        appStatePtr: pointer, `value`: sink `tupleTyp`
    ): EntityId {.nimcall, raises: [], gcsafe.} =
      let `appStateIdent` = cast[ptr `appState`](appStatePtr)
      var `entity` = `appStateIdent`.world.newEntity
      result = `entity`.entityId
      `storeComps`
      `log`

  spawnProcs[sig] = true.newLit

proc generate(
    details: GenerateContext, arg: SystemArg, name: string, dir: TupleDirective
): NimNode =
  if isFastCompileMode(fastSpawnGen):
    return newEmptyNode()

  case details.hook
  of Outside:
    return details.buildSpawnProc(dir)
  of Standard:
    # Check for max capacity, as we can produce a better error by doing it here versus doing it later
    discard maxCapacity(arg.source, dir)

    let spawnProc = details.spawnProcName(dir)
    let ident = name.ident
    return quote:
      `appStateIdent`.`ident` = newSpawn(`appStatePtr`, `spawnProc`)
  else:
    discard

let spawnGenerator* {.compileTime.} = newGenerator(
  ident = "Spawn",
  interest = {Outside, Standard},
  generate = generate,
  archetype = archetypes,
  worldFields = worldFields,
  systemArg = spawnSystemArg,
)

let fullSpawnGenerator* {.compileTime.} = newGenerator(
  ident = "FullSpawn",
  interest = {Outside, Standard},
  generate = generate,
  archetype = archetypes,
  worldFields = worldFields,
  systemArg = fullSpawnSystemArg,
)
