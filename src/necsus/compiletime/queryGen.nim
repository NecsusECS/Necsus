import directive, directiveSet, codeGenInfo, macros, componentSet, sequtils
import ../runtime/[ queryFilter, packedIntTable ]

proc queryStorageIdent*(queryName: string): NimNode =
    ## Creates an ident for referencing the storage of a query
    ident(queryName & "Storage")

proc createStorageTupleType(query: QueryDef): NimNode =
    ## Creates the tuple needed to store
    result = nnkTupleConstr.newTree()
    for component in query:
        result.add quote do: PackedIntTableValue[`component`]

proc createComponentSet(codeGenInfo: CodeGenInfo, query: QueryDef): NimNode =
    ## Creates the tuple needed to store
    result = nnkCurly.newTree()
    for component in query:
        result.add(codeGenInfo.components.componentEnumVal(component))

proc createQueryStorageInstance(codeGenInfo: CodeGenInfo, queryName: string, query: QueryDef): NimNode =
    ## Creates code for instantiating a query storage instance
    let varName = queryName.queryStorageIdent
    let componentEnum = codeGenInfo.components.enumSymbol
    let tupleType = query.createStorageTupleType()
    let componentSet = codeGenInfo.createComponentSet(query)

    return quote:
        var `varName` = newQueryStorage[`componentEnum`, `tupleType`](
            `initialSizeIdent`,
            `worldIdent`.deleted,
            filterMatching[`componentEnum`](`componentSet`)
        )

proc createQueryIterator(codeGenInfo: CodeGenInfo, queryName: string, query: QueryDef): NimNode =
    ## Creates the iterator needed to execute a query
    let procName = ident(queryName)
    let queryTupleType = query.toSeq.asTupleType
    let queryStorageName = queryName.queryStorageIdent
    let eid = ident("eid")
    let members = ident("members")

    var instantiateTuple = nnkTupleConstr.newTree()
    for (i, component) in query.toSeq.pairs:
        instantiateTuple.add quote do:
            `componentsIdent`.`component`[`members`[`i`]]

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