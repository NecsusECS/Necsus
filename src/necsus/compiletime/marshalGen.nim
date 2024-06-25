import macros, codeGenInfo, common, parse, tickGen, tools, std/[sequtils, tables, json, jsonutils, sets]

proc saveTypeName(genInfo: CodeGenInfo): NimNode = ident(genInfo.app.name & "Marshal")

proc restoreSysType(sys: ParsedSystem): NimNode =
    ## Returns the type that a restoreSys accepts for restoration
    sys.prefixArgs[0][1]

proc collectMarshalTypes(topics: openArray[NimNode], dedupe: var HashSet[string], records: var NimNode) =
    var seen = initTable[string, NimNode]()
    for topicType in topics:
        let topicName = topicType.strVal
        if topicName in seen:
            hint("Conflicting marhasling definition", seen[topicName])
            error(
                "A type named '" & topicName & "' is already returned by a different marshaling system",
                topicType
            )
        else:
            seen[topicName] = topicType
            if topicName notin dedupe:
                dedupe.incl(topicName)
                records.add(nnkIdentDefs.newTree(topicName.ident, topicType, newEmptyNode()))

proc createSaveType(genInfo: CodeGenInfo): NimNode =
    ## Generates the type definition needed to serialize an app
    if isFastCompileMode():
        return newEmptyNode()

    var records = nnkRecList.newTree()
    var dedupe = initHashSet[string]()

    genInfo.systems.filterIt(it.phase == SaveCallback).mapIt(it.returns).collectMarshalTypes(dedupe, records)
    genInfo.systems.filterIt(it.phase == RestoreCallback).mapIt(it.restoreSysType).collectMarshalTypes(dedupe, records)

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

    let body = if isFastCompileMode():
        newStmtList()
    else:
        let saveTypeName = genInfo.saveTypeName

        var invocations = newStmtList()
        for restore in genInfo.systems.filterIt(it.phase == RestoreCallback):
            let readProp = newDotExpr(decoded, restore.restoreSysType.strVal.ident)
            invocations.add(genInfo.invokeSystem(restore, {RestoreCallback}, [ readProp ]))

        let log = emitSaveTrace("Restoring from ", streamIdent, " as ", decoded)
        quote:
            var `decoded`: `saveTypeName`
            fromJson(`decoded`, parseJson(`streamIdent`))
            `log`
            `invocations`

    return quote:
        proc restore*(
            `appStateIdent`: var `appStateType`,
            `streamIdent`: string
        ) {.gcsafe, raises: [IOError, OSError, JsonParsingError, ValueError, Exception].} =
            `body`

proc createSaveProc(genInfo: CodeGenInfo): NimNode =
    ## Generates a proc that calls all the 'save' systems and aggregates them into a single value
    let appStateType = genInfo.appStateTypeName

    let body = if isFastCompileMode():
        newStmtList()
    else:
        var construct = nnkObjConstr.newTree(genInfo.saveTypeName)
        for system in genInfo.systems.filterIt(it.phase == SaveCallback):
            construct.add(
                nnkExprColonExpr.newTree(
                    system.returns.strVal.ident,
                    genInfo.invokeSystem(system, {SaveCallback})
                )
            )

        let log = emitSaveTrace("Saved: ", ident("result"))

        quote:
            result = $toJson(`construct`)
            `log`

    return quote:
        {.hint[XCannotRaiseY]:off.}
        proc save*(
            `appStateIdent`: var `appStateType`,
        ): string {.raises: [IOError, OSError, ValueError, Exception].} =
            `body`

proc createMarshalProcs*(genInfo: CodeGenInfo): NimNode =
    ## Generates procs needed for saving and restoring game state
    return newStmtList(createSaveType(genInfo), createSaveProc(genInfo), createRestoreProc(genInfo))