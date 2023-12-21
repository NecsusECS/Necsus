import tables, macros
import archetype, tools, systemGen, archetypeBuilder, worldEnum, commonVars
import ../runtime/[archetypeStore, world, directives]

proc worldFields(name: string): seq[WorldField] = @[ (name, bindSym("Delete")) ]

proc generate(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    ## Generates the code for deleting an entity
    case details.hook
    of GenerateHook.Standard:
        let deleteProc = name.ident
        let archetypeEnum = details.archetypeEnum.ident
        let entity = ident("entity")
        let entityIndex = ident("entityIndex")

        var cases: NimNode
        if details.archetypes.len > 0:
            cases = nnkCaseStmt.newTree(newDotExpr(entityIndex, ident("archetype")))
            for (ofBranch, archetype) in archetypeCases(details):
                let archIdent = archetype.ident
                let deleteCall = quote:
                    del(`appStateIdent`.`archIdent`, `entityIndex`.archetypeIndex)
                cases.add(nnkOfBranch.newTree(ofBranch, deleteCall))
        else:
            cases = newEmptyNode()

        return quote do:
            `appStateIdent`.`deleteProc` = proc(`entity`: EntityId) =
                let `entityIndex` = del[`archetypeEnum`](`appStateIdent`.`worldIdent`, `entity`)
                `cases`
    else:
        return newEmptyNode()

let deleteGenerator* {.compileTime.} = newGenerator(
    ident = "Delete",
    interest = { Standard },
    generate = generate,
    worldFields = worldFields
)