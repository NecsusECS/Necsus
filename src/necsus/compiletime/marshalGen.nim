import macros, codeGenInfo, commonVars, parse, tickGen, std/[sequtils, marshal, tables, streams]

proc saveTypeName(genInfo: CodeGenInfo): NimNode = ident(genInfo.app.name & "Marshal")

proc createSaveType(genInfo: CodeGenInfo, saves: openArray[ParsedSystem]): NimNode =
    ## Generates the type definition needed to serialize an app
    var records = nnkRecList.newTree()

    var seen = initTable[string, NimNode]()
    for system in saves:
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

proc createSaveProc*(genInfo: CodeGenInfo): NimNode =
    ## Generates a proc that calls all the 'save' systems and aggregates them into a single value
    let appStateType = genInfo.appStateTypeName

    let saves = genInfo.systems.filterIt(it.phase == SaveCallback)
    let saveType = genInfo.createSaveType(saves)

    var construct = nnkObjConstr.newTree(genInfo.saveTypeName)
    for system in saves:
        construct.add(nnkExprColonExpr.newTree(system.returns.strVal.ident, genInfo.invokeSystem(system, SaveCallback)))

    return quote:
        `saveType`

        proc saveTo*(
            `appStateIdent`: var `appStateType`,
            `streamIdent`: var Stream
        ) {.gcsafe, raises: [IOError, OSError, ValueError].} =
            store(`streamIdent`, `construct`)

        proc save*(
            `appStateIdent`: var `appStateType`
        ): string {.used, gcsafe, raises: [IOError, OSError, ValueError].} =
            var `streamIdent`: Stream = newStringStream("")
            saveTo(`appStateIdent`, `streamIdent`)
            `streamIdent`.setPosition(0)
            return `streamIdent`.readAll()
