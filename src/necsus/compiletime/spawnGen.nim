import macros, sequtils, sets
import tools, codeGenInfo, directiveSet, tupleDirective, archetype, commonVars
import ../runtime/spawn

proc createSpawnProcs*(codeGenInfo: CodeGenInfo): NimNode =
    ## Creates a `proc` for spawning an entity with a specific set of components
    result = newStmtList()

    for (name, spawnDef) in codeGenInfo.spawns:
        let ident = name.ident
        let spawnTuple = spawnDef.args.toSeq.asTupleType
        let archetype = codeGenInfo.archetypes[spawnDef.items.toSeq]
        let archetypeIdent = archetype.ident
        result.add quote do:
            let `ident` = newSpawn[`spawnTuple`](proc(): auto = beginSpawn(`worldIdent`, `archetypeIdent`))
