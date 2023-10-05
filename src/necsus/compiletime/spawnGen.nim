import macros, sequtils, sets
import tools, tupleDirective, archetype, archetypeBuilder, componentDef, commonVars, systemGen
import ../runtime/spawn

proc archetypes(builder: var ArchetypeBuilder[ComponentDef], dir: TupleDirective) =
    builder.define(dir.comps)

proc worldFields(name: string, dir: TupleDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("RawSpawn"), dir.asTupleType)) ]

proc systemArg(name: string, dir: TupleDirective): NimNode =
    let sysIdent = name.ident
    let tupleType = dir.asTupleType
    return quote do:
        Spawn[`tupleType`](`appStateIdent`.`sysIdent`)

proc generate(details: GenerateContext, arg: SystemArg, name: string, dir: TupleDirective): NimNode =
    result = newStmtList()
    case details.hook
    of Standard:
        let ident = name.ident
        let archetype = details.archetypes[dir.items.toSeq]
        let archetypeIdent = archetype.ident
        result.add quote do:
            `appStateIdent`.`ident` =
                proc(): auto = beginSpawn(`appStateIdent`.`worldIdent`, `appStateIdent`.`archetypeIdent`)
    else:
        discard


let spawnGenerator* {.compileTime.} = newGenerator(
    ident = "Spawn",
    generate = generate,
    archetype = archetypes,
    worldFields = worldFields,
    systemArg = systemArg
)