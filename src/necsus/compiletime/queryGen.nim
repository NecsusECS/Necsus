import tupleDirective, directiveSet, codeGenInfo, macros, componentSet, sequtils, sets, componentDef
import ../runtime/[ queryFilter, packedIntTable ]

proc queryStorageIdent*(queryName: string): NimNode =
    ## Creates an ident for referencing the storage of a query
    ident(queryName & "_storage")

proc createStorageTupleType(query: QueryDef): NimNode =
    ## Creates the tuple needed to store
    result = nnkTupleConstr.newTree()
    for arg in query.args:
        case arg.kind
        of Include:
            let component = arg.component
            result.add quote do: PackedIntTableValue[`component`]
        of Exclude:
            discard

proc createQueryFilter(codeGenInfo: CodeGenInfo, query: QueryDef): NimNode =
    ## Creates the code to define a query filter
    var matches = initHashSet[ComponentDef]()
    var excluding = initHashSet[ComponentDef]()
    for arg in query.args:
        case arg.kind
        of Include: matches.incl(arg.component)
        of Exclude: excluding.incl(arg.component)

    let componentEnum = codeGenInfo.components.enumSymbol

    let matchesSet = codeGenInfo.createComponentSet(matches.toSeq)
    result = quote:
        filterMatching[`componentEnum`](`matchesSet`)

    if excluding.len > 0:
        let excludingSet = codeGenInfo.createComponentSet(excluding.toSeq)
        result = quote:
            filterBoth[`componentEnum`](`result`, filterExcluding[`componentEnum`](`excludingSet`))

proc createQueryStorageInstance(codeGenInfo: CodeGenInfo, queryName: string, query: QueryDef): NimNode =
    ## Creates code for instantiating a query storage instance
    let varName = queryName.queryStorageIdent
    let componentEnum = codeGenInfo.components.enumSymbol
    let tupleType = query.createStorageTupleType()
    let queryFilter = codeGenInfo.createQueryFilter(query)

    return quote:
        var `varName` = newQueryStorage[`componentEnum`, `tupleType`](`confIdent`.componentSize, `queryFilter`)

proc createQueryIterator(codeGenInfo: CodeGenInfo, queryName: string, query: QueryDef): NimNode =
    ## Creates the iterator needed to execute a query
    let procName = ident(queryName)
    let queryTupleType = query.args.asTupleType
    let queryStorageName = queryName.queryStorageIdent
    let eid = ident("eid")
    let members = ident("members")

    var instantiateTuple = nnkTupleConstr.newTree()
    for (i, arg) in query.args.toSeq.pairs:
        let component = arg.component.componentStoreIdent
        case arg.kind
        of Include:
            if arg.isPointer:
                instantiateTuple.add quote do: getPointer(`component`, `members`[`i`])
            else:
                instantiateTuple.add quote do: `component`[`members`[`i`]]
        of Exclude:
            let componentType = arg.component
            instantiateTuple.add quote do: cast[Not[`componentType`]](0'i8)

    return quote:
        proc `procName`(): auto =
            return iterator(): QueryItem[`queryTupleType`] {.closure.} =
                for (`eid`, `members`) in values(`queryStorageName`):
                    yield (`eid`, `instantiateTuple`)

proc createQueries*(codeGenInfo: CodeGenInfo): NimNode =
    ## Creates the storage blocks and iterators for all the queries
    result = newStmtList()

    for (name, query) in codeGenInfo.queries:
        result.add(codeGenInfo.createQueryStorageInstance(name, query))
        result.add(codeGenInfo.createQueryIterator(name, query))
