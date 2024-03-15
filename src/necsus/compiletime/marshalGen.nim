import macros, codeGenInfo, commonVars, parse, tickGen, std/[sequtils, marshal, tables, streams, json]

proc saveTypeName(genInfo: CodeGenInfo): NimNode = ident(genInfo.app.name & "Marshal")

proc createSaveType(genInfo: CodeGenInfo): NimNode =
    ## Generates the type definition needed to serialize an app
    var records = nnkRecList.newTree()

    var seen = initTable[string, NimNode]()
    for system in genInfo.systems.filterIt(it.phase == SaveCallback):
        if system.returns.strVal in seen:
            hint("Conflicting save system definition", seen[system.returns.strVal])
            error(
                "A type named '" & system.returns.strVal & "' is already returned by a different save system",
                system.returns
            )
        else:
            seen[system.returns.strVal] = system.returns
            records.add(
                nnkIdentDefs.newTree(
                    system.returns.strVal.ident,
                    system.returns,
                    newEmptyNode()
                )
            )

    return nnkTypeSection.newTree(
        nnkTypeDef.newTree(
            genInfo.saveTypeName,
            newEmptyNode(),
            nnkObjectTy.newTree(newEmptyNode(), newEmptyNode(), records)
        )
    )

let streamIdent {.compileTime.} = "stream".ident
let decoded {.compileTime.} = "decoded".ident

proc createRestoreProc(genInfo: CodeGenInfo): NimNode =
    ## Generates a proc that is able to restore all procs
    let appStateType = genInfo.appStateTypeName

    let saveTypeName = genInfo.saveTypeName

    let saves = genInfo.systems.filterIt(it.phase == SaveCallback).mapIt(it.returns.strVal)

    var invocations = newStmtList()
    for restore in genInfo.systems.filterIt(it.phase == RestoreCallback):
        let restoreType = restore.prefixArgs[0][1]
        if restoreType.strVal in saves:
            let readProp = newDotExpr(decoded, restoreType.strVal.ident)
            invocations.add(genInfo.invokeSystem(restore, RestoreCallback, [ readProp ]))

    return quote:
        proc restore*(
            `appStateIdent`: var `appStateType`,
            `streamIdent`: var Stream
        ) {.gcsafe, raises: [IOError, OSError, JsonParsingError, ValueError, Exception].} =
            var `decoded`: `saveTypeName`
            load(`streamIdent`, `decoded`)
            `invocations`

proc createSaveProc(genInfo: CodeGenInfo): NimNode =
    ## Generates a proc that calls all the 'save' systems and aggregates them into a single value
    let appStateType = genInfo.appStateTypeName

    var construct = nnkObjConstr.newTree(genInfo.saveTypeName)
    for system in genInfo.systems.filterIt(it.phase == SaveCallback):
        construct.add(nnkExprColonExpr.newTree(system.returns.strVal.ident, genInfo.invokeSystem(system, SaveCallback)))

    return quote:
        {.hint[XCannotRaiseY]:off.}
        proc save*(
            `appStateIdent`: var `appStateType`,
            `streamIdent`: var Stream
        ) {.raises: [IOError, OSError, ValueError, Exception].} =
            store(`streamIdent`, `construct`)

proc createMarshalProcs*(genInfo: CodeGenInfo): NimNode =
    ## Generates procs needed for saving and restoring game state
    return newStmtList(createSaveType(genInfo), createSaveProc(genInfo), createRestoreProc(genInfo))