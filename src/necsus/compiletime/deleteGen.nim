import tables, macros
import archetype, tools, systemGen, archetypeBuilder, worldEnum, common
import ../runtime/[archetypeStore, world, directives]

proc worldFields(name: string): seq[WorldField] = @[ (name, bindSym("Delete")) ]

let entity {.compileTime.} = ident("entity")
let entityIndex {.compileTime.} = ident("entityIndex")

proc generate(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    ## Generates the code for deleting an entity

    let deleteProcName = details.globalName(name)

    case details.hook
    of Outside:
        let archetypeEnum = details.archetypeEnum.ident
        let appStateTypeName = details.appStateTypeName

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

        let log = emitEntityTrace("Deleting ", entity)

        return quote do:
            proc `deleteProcName`(`appStateIdent`: var `appStateTypeName`, `entity`: EntityId) {.gcsafe, raises: [].} =
                let `entityIndex` = del[`archetypeEnum`](`appStateIdent`.`worldIdent`, `entity`)
                `log`
                `cases`
    of Standard:
        let deleteProc = name.ident
        return quote do:
            `appStateIdent`.`deleteProc` = proc(`entity`: EntityId) = `deleteProcName`(`appStateIdent`, `entity`)
    else:
        return newEmptyNode()

let deleteGenerator* {.compileTime.} = newGenerator(
    ident = "Delete",
    interest = { Standard, Outside },
    generate = generate,
    worldFields = worldFields
)