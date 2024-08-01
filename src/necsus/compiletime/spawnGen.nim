import std/[macros, sequtils, sets, macrocache]
import tools, tupleDirective, archetype, archetypeBuilder, componentDef, common, systemGen
import ../runtime/[spawn, archetypeStore, world]

proc archetypes(builder: var ArchetypeBuilder[ComponentDef], systemArgs: seq[SystemArg], dir: TupleDirective) =
    builder.define(dir.comps)

proc worldFields(name: string, dir: TupleDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("RawSpawn"), dir.asTupleType)) ]

proc systemArg(spawnType: NimNode, name: string, dir: TupleDirective): NimNode =
    let sysIdent = name.ident
    let tupleType = dir.asTupleType
    return quote do:
        `spawnType`[`tupleType`](`appStateIdent`.`sysIdent`)

proc spawnSystemArg(name: string, dir: TupleDirective): NimNode = systemArg(bindSym("Spawn"), name, dir)

proc fullSpawnSystemArg(name: string, dir: TupleDirective): NimNode = systemArg(bindSym("FullSpawn"), name, dir)

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

proc buildSpawnProc(details: GenerateContext, dir: TupleDirective): NimNode =
    ## Builds the proc needed to execute a spawn against the given tuple
    let sig = details.globalStr(dir.signature)
    if sig in spawnSymbols:
        return spawnSymbols[sig]

    let appState = details.appStateTypeName
    let spawnProc = details.spawnProcName(dir)
    let archetype = newArchetype(dir.items.toSeq)
    let archIdent = archetype.ident
    let log = emitEntityTrace("Spawned ", ident("result"), " of kind ", archetype.name)
    let tupleTyp = dir.asTupleType
    result = quote:
        proc `spawnProc`(
            appStatePtr: pointer,
            value: sink `tupleTyp`
        ): EntityId {.fastcall, raises: [], gcsafe.} =
            let `appStateIdent` = cast[ptr `appState`](appStatePtr)
            var newEntity = `appStateIdent`.world.newEntity
            var slot = newSlot(`appStateIdent`.`archIdent`, newEntity.entityId)
            newEntity.setArchetypeDetails(readArchetype[`tupleTyp`](`appStateIdent`.`archIdent`), slot.index)
            result = setComp(slot, value)
            `log`

    spawnProcs[sig] = result

proc generate(details: GenerateContext, arg: SystemArg, name: string, dir: TupleDirective): NimNode =
    case details.hook
    of Outside:
        return details.buildSpawnProc(dir)
    of Standard:
        try:
            let spawnProc = details.spawnProcName(dir)
            let ident = name.ident
            return quote do:
                `appStateIdent`.`ident` = newSpawn(`appStatePtr`, `spawnProc`)
        except UnsortedArchetype as e:
            error(e.msg, arg.source)
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