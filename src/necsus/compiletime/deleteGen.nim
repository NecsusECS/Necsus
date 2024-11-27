import tables, macros
import archetype, tools, systemGen, archetypeBuilder, common, tupleDirective
import ../runtime/[archetypeStore, world, directives]

proc deleteFields(name: string): seq[WorldField] = @[ (name, bindSym("Delete")) ]

let entity {.compileTime.} = ident("entity")
let entityIndex {.compileTime.} = ident("entityIndex")

proc deleteProcName(details: GenerateContext): NimNode =
    return details.globalName("internalDelete")

proc generateDelete(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    ## Generates the code for deleting an entity

    let deleteProcName = details.deleteProcName

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
    generate = generateDelete,
    worldFields = deleteFields
)

proc deleteAllFields(name: string, dir: TupleDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("DeleteAll"), dir.asTupleType)) ]

proc deleteAllBody(details: GenerateContext, dir: TupleDirective): NimNode =
    let deleteProcName = details.deleteProcName
    result = newStmtList()
    for archetype in details.archetypes:
        if archetype.matches(dir.filter):
            let archetypeIdent = archetype.ident
            result.add quote do:
                for eid in entityIds(`appStateIdent`.`archetypeIdent`):
                    `deleteProcName`(`appStatePtr`, eid)

proc generateDeleteAll(details: GenerateContext, arg: SystemArg, name: string, dir: TupleDirective): NimNode =

    let deleteAllImpl = details.globalName(name)

    case details.hook
    of Outside:
        let appStateTypeName = details.appStateTypeName
        let body = details.deleteAllBody(dir)
        return quote:
            proc `deleteAllImpl`(`appStatePtr`: pointer) {.gcsafe, raises: [ValueError], fastcall.} =
                let `appStateIdent` {.used.} = cast[ptr `appStateTypeName`](`appStatePtr`)
                `body`
    of Standard:
        let ident = name.ident
        return quote do:
            `appStateIdent`.`ident` = newCallbackDir(`appStatePtr`, `deleteAllImpl`)
    else:
        return newEmptyNode()

proc deleteAllNestedArgs(dir: TupleDirective): seq[RawNestedArg] =
    @[ (newEmptyNode(), "del".ident, bindSym("Delete")) ]

let deleteAllGenerator* {.compileTime.} = newGenerator(
    ident = "DeleteAll",
    interest = { Standard, Outside },
    generate = generateDeleteAll,
    worldFields = deleteAllFields,
    nestedArgs = deleteAllNestedArgs,
)
