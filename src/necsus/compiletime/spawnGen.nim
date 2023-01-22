import macros, sequtils, sets
import tools, tupleDirective, archetype, archetypeBuilder, componentDef, commonVars, systemGen
import ../runtime/spawn

proc archetypes(builder: var ArchetypeBuilder[ComponentDef], dir: TupleDirective) =
    builder.define(dir.comps)

proc worldFields(name: string, dir: TupleDirective): seq[WorldField] =
     @[ (name, nnkBracketExpr.newTree(bindSym("Spawn"), dir.asTupleType)) ]

proc generate(details: GenerateContext, dir: TupleDirective): NimNode =
    result = newStmtList()
    case details.hook
    of Standard:
        let ident = details.name.ident
        let spawnTuple = dir.asTupleType
        let archetype = details.archetypes[dir.items.toSeq]
        let archetypeIdent = archetype.ident
        result.add quote do:
            let `ident` = newSpawn[`spawnTuple`](proc(): auto = beginSpawn(`worldIdent`, `archetypeIdent`))
    else:
        discard


let spawnGenerator* {.compileTime.} = newGenerator(
    ident = "Spawn",
    generate = generate,
    archetype = archetypes,
    worldFields = worldFields
)