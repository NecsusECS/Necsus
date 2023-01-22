import macros, sequtils, sets
import tools, tupleDirective, archetype, archetypeBuilder, componentDef, commonVars, systemGen
import ../runtime/spawn

proc archetypeTuple(builder: var ArchetypeBuilder[ComponentDef], dir: TupleDirective) =
    builder.define(dir.comps)

proc generateTuple(details: GenerateContext, dir: TupleDirective): NimNode =
    result = newStmtList()
    case details.hook
    of Standard:
        let ident = details.name.ident
        let spawnTuple = dir.args.toSeq.asTupleType
        let archetype = details.archetypes[dir.items.toSeq]
        let archetypeIdent = archetype.ident
        result.add quote do:
            let `ident` = newSpawn[`spawnTuple`](proc(): auto = beginSpawn(`worldIdent`, `archetypeIdent`))
    else:
        discard

let spawnGenerator* {.compileTime.} = newGenerator("Spawn", generateTuple, archetypeTuple)