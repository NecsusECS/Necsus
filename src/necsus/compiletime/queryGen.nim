import tupleDirective, directiveSet, codeGenInfo, macros, componentEnum, sequtils, sets, componentDef
import ../runtime/[ queryFilter, packedIntTable ]

proc queryStorageIdent*(queryName: string): NimNode =
    ## Creates an ident for referencing the storage of a query
    ident(queryName & "_storage")

proc createStorageTupleType(query: QueryDef): NimNode =
    ## Creates the tuple needed to store
    result = nnkTupleConstr.newTree()
    for arg in query.args:
        let component = arg.component
        case arg.kind
        of Include:
            result.add quote do: PackedIntTableValue[`component`]
        of Exclude:
            discard
        of Optional:
            discard

proc createQueryFilter(codeGenInfo: CodeGenInfo, query: QueryDef): NimNode =
    ## Creates the code to define a query filter
    var matches = initHashSet[ComponentDef]()
    var excluding = initHashSet[ComponentDef]()
    for arg in query.args:
        case arg.kind
        of Include: matches.incl(arg.component)
        of Exclude: excluding.incl(arg.component)
        of Optional: discard

    let componentEnum = codeGenInfo.components.enumSymbol

    let matchesSet = codeGenInfo.createComponentEnum(matches.toSeq)
    result = quote:
        filterMatching[`componentEnum`](`matchesSet`)

    if excluding.len > 0:
        let excludingSet = codeGenInfo.createComponentEnum(excluding.toSeq)
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


let eid {.compileTime.} = ident("eid")
let members {.compileTime.} = ident("members")

proc instantiateQueryTuple(codeGenInfo: CodeGenInfo, query: QueryDef): NimNode =
    ## Creates the code for instantiating the QueryItem tuple produced by a query
    result = nnkTupleConstr.newTree()
    for (i, arg) in query.args.toSeq.pairs:
        let component = arg.component.componentStoreIdent
        case arg.kind
        of Include:
            if arg.isPointer:
                result.add quote do: getPointer(`component`, `members`[`i`])
            else:
                result.add quote do: `component`[`members`[`i`]]
        of Exclude:
            let componentType = arg.component
            result.add quote do: cast[Not[`componentType`]](0'i8)
        of Optional:
            if arg.isPointer:
                result.add quote do: maybeGetPointer(`component`, `eid`.int32)
            else:
                result.add quote do: maybeGet(`component`, `eid`.int32)

proc createQueryIterator(codeGenInfo: CodeGenInfo, queryName: string, query: QueryDef): NimNode =
    ## Creates the iterator needed to execute a query
    let procName = ident(queryName)
    let queryTupleType = query.args.asTupleType
    let queryStorageName = queryName.queryStorageIdent
    var instantiateTuple = codeGenInfo.instantiateQueryTuple(query)
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
