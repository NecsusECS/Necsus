import tables, macros
import archetype, tools, systemGen, archetypeBuilder, common
import ../runtime/[archetypeStore, world, directives]

proc worldFields(name: string): seq[WorldField] = @[ (name, bindSym("Delete")) ]

let entity {.compileTime.} = ident("entity")
let entityIndex {.compileTime.} = ident("entityIndex")

proc generate(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    ## Generates the code for deleting an entity

    let deleteProcName = details.globalName(name)

    case details.hook
    of Outside:
        let appStateTypeName = details.appStateTypeName

        let body = if isFastCompileMode(fastDelete):
            newStmtList()
        else:
            var cases: NimNode
            if details.archetypes.len > 0:
                cases = nnkCaseStmt.newTree(newDotExpr(entityIndex, ident("archetype")))
                for (ofBranch, archetype) in archetypeCases(details):
                    let archIdent = archetype.ident
                    let deleteCall = quote:
                        del(`appStateIdent`.`archIdent`, `entityIndex`.archetypeIndex)
                    cases.add(nnkOfBranch.newTree(ofBranch, deleteCall))

                cases.add(nnkElse.newTree(nnkDiscardStmt.newTree(newEmptyNode())))
            else:
                cases = newEmptyNode()

            let log = emitEntityTrace("Deleting ", entity)

            quote:
                let `entityIndex` = del(`appStateIdent`.`worldIdent`, `entity`)
                `log`
                `cases`

        return quote do:
            proc `deleteProcName`(`appStateIdent`: pointer, `entity`: EntityId) {.gcsafe, raises: [], fastcall, used.} =
                let `appStateIdent` {.used.} = cast[ptr `appStateTypeName`](`appStateIdent`)
                `body`
    of Standard:
        let deleteProc = name.ident
        return quote do:
            `appStateIdent`.`deleteProc` = newCallbackDir(`appStatePtr`, `deleteProcName`)
    else:
        return newEmptyNode()

let deleteGenerator* {.compileTime.} = newGenerator(
    ident = "Delete",
    interest = { Standard, Outside },
    generate = generate,
    worldFields = worldFields
)