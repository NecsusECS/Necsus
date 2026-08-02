import std/[macros, options]
import
  tools, tupleDirective, archetype, archetypeBuilder, componentDef, common, systemGen
import ../runtime/[spawn, archetypeStore, world]

proc archetypes(
    builder: var ArchetypeBuilder[ComponentDef],
    systemArgs: seq[SystemArg],
    dir: TupleDirective,
) =
  builder.define(dir.comps)

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
    if present:
      result.add(
        newCall(
          nnkBracketExpr.newTree(setComponent, component.ident),
          store,
          component.columnId,
          index,
          nnkBracketExpr.newTree(readFrom, dir.indexOf(component).newLit),
        )
      )

    if component.isAccessory:
      result.add(
        newCall(
          nnkBracketExpr.newTree(setComponent, bindSym("AccessoryFlag")),
          store,
          component.presenceColumnId,
          index,
          newLit(present),
        )
      )

proc buildSpawnProc(details: GenerateContext, dir: TupleDirective): NimNode =
  ## Builds the proc needed to execute a spawn against the given tuple
  let sig = details.globalStr(dir.signature)
  if sig in spawnProcs:
    return newEmptyNode()

  let appState = details.appStateTypeName
  let spawnProc = details.spawnProcName(dir)
  let archetype = details.archetypeFor(dir)
  let archIdent = archetype.ident
  let archetypeRef = archetype.idSymbol
  let value = genSym(nskParam, "value")
  let index = genSym(nskLet, "index")
  let log = emitEntityTrace("Spawned ", ident("result"), " of kind ", $dir)
  let tupleTyp = dir.asTupleType

  let store = quote:
    `appStateIdent`.`archIdent`

  let storeComps = archetype.storeComponents(dir, store, index, value)

  result = quote:
    proc `spawnProc`(
        appStatePtr: pointer, `value`: sink `tupleTyp`
    ): EntityId {.nimcall, raises: [], gcsafe.} =
      let `appStateIdent` = cast[ptr `appState`](appStatePtr)
      var newEntity = `appStateIdent`.world.newEntity
      result = newEntity.entityId
      let `index` = reserve(`appStateIdent`.`archIdent`, result)
      newEntity.setArchetypeDetails(`archetypeRef`, uint(`index`))
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
