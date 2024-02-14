import macros, sequtils, sets
import tools, tupleDirective, archetype, archetypeBuilder, componentDef, commonVars, systemGen
import ../runtime/spawn

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

proc generate(details: GenerateContext, arg: SystemArg, name: string, dir: TupleDirective): NimNode =
    result = newStmtList()
    case details.hook
    of Standard:
        try:
            let ident = name.ident
            let archetype = newArchetype(dir.items.toSeq)
            let archetypeIdent = archetype.ident
            result.add quote do:
                `appStateIdent`.`ident` =
                    proc(): auto = beginSpawn(`appStateIdent`.`worldIdent`, `appStateIdent`.`archetypeIdent`)
        except UnsortedArchetype as e:
            error(e.msg, arg.source)
    else:
        discard


let spawnGenerator* {.compileTime.} = newGenerator(
    ident = "Spawn",
    interest = { Standard },
    generate = generate,
    archetype = archetypes,
    worldFields = worldFields,
    systemArg = spawnSystemArg
)

let fullSpawnGenerator* {.compileTime.} = newGenerator(
    ident = "FullSpawn",
    interest = { Standard },
    generate = generate,
    archetype = archetypes,
    worldFields = worldFields,
    systemArg = fullSpawnSystemArg,
)