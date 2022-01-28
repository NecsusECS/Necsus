import tupleDirective, directiveSet, codeGenInfo, macros, componentSet, sequtils
import ../runtime/[ queryFilter, packedIntTable ]

proc queryStorageIdent*(queryName: string): NimNode =
    ## Creates an ident for referencing the storage of a query
    ident(queryName & "Storage")

proc createStorageTupleType(query: QueryDef): NimNode =
    ## Creates the tuple needed to store
    result = nnkTupleConstr.newTree()
    for component in query:
        result.add quote do: PackedIntTableValue[`component`]

proc createQueryStorageInstance(codeGenInfo: CodeGenInfo, queryName: string, query: QueryDef): NimNode =
    ## Creates code for instantiating a query storage instance
    let varName = queryName.queryStorageIdent
    let componentEnum = codeGenInfo.components.enumSymbol
    let tupleType = query.createStorageTupleType()
    let componentSet = codeGenInfo.createComponentSet(query.toSeq)

    return quote:
        var `varName` = newQueryStorage[`componentEnum`, `tupleType`](
            `confIdent`.componentSize,
            filterMatching[`componentEnum`](`componentSet`)
        )

proc createQueryIterator(codeGenInfo: CodeGenInfo, queryName: string, query: QueryDef): NimNode =
    ## Creates the iterator needed to execute a query
    let procName = ident(queryName)
    let queryTupleType = query.args.toSeq.asTupleType
    let queryStorageName = queryName.queryStorageIdent
    let eid = ident("eid")
    let members = ident("members")

    var instantiateTuple = nnkTupleConstr.newTree()
    for (i, arg) in query.args.toSeq.pairs:
        let component = arg.component.componentStoreIdent
        if arg.isPointer:
            instantiateTuple.add quote do: getPointer(`component`, `members`[`i`])
        else:
            instantiateTuple.add quote do: `component`[`members`[`i`]]

    return quote:
        proc `procName`(): auto =
            return iterator(): QueryItem[`queryTupleType`] {.closure.} =
                for (`eid`, `members`) in `queryStorageName`:
                    yield (`eid`, `instantiateTuple`)

proc createQueries*(codeGenInfo: CodeGenInfo): NimNode =
    ## Creates the storage blocks and iterators for all the queries
    result = newStmtList()

    for (name, query) in codeGenInfo.queries:
        result.add(codeGenInfo.createQueryStorageInstance(name, query))
        result.add(codeGenInfo.createQueryIterator(name, query))
