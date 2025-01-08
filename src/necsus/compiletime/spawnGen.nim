import std/[macros, sets, macrocache, options]
import tools, tupleDirective, archetype, archetypeBuilder, componentDef, common, systemGen
import ../runtime/[spawn, archetypeStore, world]

proc archetypes(builder: var ArchetypeBuilder[ComponentDef], systemArgs: seq[SystemArg], dir: TupleDirective) =
    builder.define(dir.comps)

proc worldFields(name: string, dir: TupleDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("RawSpawn"), dir.asTupleType)) ]

proc systemArg(spawnType: NimNode, name: string): NimNode =
    let sysIdent = name.ident
    return quote do:
        `appStateIdent`.`sysIdent`.`spawnType`

proc spawnSystemArg(name: string, dir: TupleDirective): NimNode = systemArg(bindSym("asSpawn"), name)

proc fullSpawnSystemArg(name: string, dir: TupleDirective): NimNode = systemArg(bindSym("asFullSpawn"), name)

when NimMajor >= 2:
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

proc convertSpawnValue(archetype: Archetype[ComponentDef], dir: TupleDirective, readFrom: NimNode): NimNode =
    ## Generates code for taking a tuple and converting it to the archetype in which it is being stored
    if archetype.hasAccessories or archetype.asTupleDir.comps != dir.comps:
        result = nnkTupleConstr.newTree()
        for component in archetype.values:
            if component in dir:
                let read = nnkBracketExpr.newTree(readFrom, dir.indexOf(component).newLit)
                result.add(if component.isAccessory: newCall(bindSym("some"), read) else: read)
            else:
                result.add(newCall(nnkBracketExpr.newTree(bindSym("none"), component.node)))
    else:
        result = readFrom

proc buildSpawnProc(details: GenerateContext, dir: TupleDirective): NimNode =
    ## Builds the proc needed to execute a spawn against the given tuple
    let sig = details.globalStr(dir.signature)
    if sig in spawnProcs:
        return newEmptyNode()

    let appState = details.appStateTypeName
    let spawnProc = details.spawnProcName(dir)
    let archetype = details.archetypeFor(dir)
    let archIdent = archetype.ident
    let value = genSym(nskParam, "value")
    let construct = archetype.convertSpawnValue(dir, value)
    let log = emitEntityTrace("Spawned ", ident("result"), " of kind ", $dir)
    let tupleTyp = dir.asTupleType

    result = quote:
        proc `spawnProc`(
            appStatePtr: pointer,
            `value`: sink `tupleTyp`
        ): EntityId {.nimcall, raises: [], gcsafe.} =
            let `appStateIdent` = cast[ptr `appState`](appStatePtr)
            var newEntity = `appStateIdent`.world.newEntity
            var slot = newSlot(`appStateIdent`.`archIdent`, newEntity.entityId)
            newEntity.setArchetypeDetails(readArchetype(`appStateIdent`.`archIdent`), slot.index)
            result = setComp(slot, `construct`)
            `log`

    spawnProcs[sig] = true.newLit

proc generate(details: GenerateContext, arg: SystemArg, name: string, dir: TupleDirective): NimNode =

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
        return quote do:
            `appStateIdent`.`ident` = newSpawn(`appStatePtr`, `spawnProc`)
    else:
        discard

let spawnGenerator* {.compileTime.} = newGenerator(
    ident = "Spawn",
    interest = { Outside, Standard },
    generate = generate,
    archetype = archetypes,
    worldFields = worldFields,
    systemArg = spawnSystemArg
)

let fullSpawnGenerator* {.compileTime.} = newGenerator(
    ident = "FullSpawn",
    interest = { Outside, Standard },
    generate = generate,
    archetype = archetypes,
    worldFields = worldFields,
    systemArg = fullSpawnSystemArg,
)
