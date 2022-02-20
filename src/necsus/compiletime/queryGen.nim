import tupleDirective, directiveSet, codeGenInfo, macros, componentEnum, sequtils, sets, componentDef, grouper
import ../runtime/queryFilter, necsusUtil/packedIntTable

proc queryStorageIdent*(queryName: string): NimNode =
    ## Creates an ident for referencing the storage of a query
    ident(queryName & "_storage")

iterator queryGroups*(codeGenInfo: CodeGenInfo, query: QueryDef): tuple[group: Group[ComponentDef], optional: bool] =
    ## Produce the ordered unique component groups in a query
    var seen = initHashSet[Group[ComponentDef]]()
    for arg in query.args:
        case arg.kind
        of Include, Optional:
            let group = codeGenInfo.compGroups[arg.component]
            if group notin seen:
                seen.incl group
                yield (group, arg.kind == Optional)
        of Exclude:
            discard

proc createStorageTupleType(codeGenInfo: CodeGenInfo, query: QueryDef): NimNode =
    ## Creates the tuple type needed to store the components for an entity in a query
    result = nnkTupleConstr.newTree()
    for (group, isOptional) in codeGenInfo.queryGroups(query):
        if not isOptional:
            let groupType = group.asStorageTuple
            result.add quote do: PackedIntTableValue[`groupType`]

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
    let tupleType = codeGenInfo.createStorageTupleType(query)
    let queryFilter = codeGenInfo.createQueryFilter(query)

    return quote:
        var `varName` = newQueryStorage[`componentEnum`, `tupleType`](`confIdent`.componentSize, `queryFilter`)


let eid {.compileTime.} = ident("eid")
let members {.compileTime.} = ident("members")

proc localGroupIdent(group: Group[ComponentDef]): NimNode =
    ## Defines the local variable used to store components for each element in a query
    ident("entity_comps_" & group.name)

proc createCompStoreVariables(codeGenInfo: CodeGenInfo, query: QueryDef): NimNode =
    ## Creates code that pulls components out of storage for each member of a query
    result = newStmtList()
    for i, (group, isOptional) in codeGenInfo.queryGroups(query).toSeq:
        let compStoreIdent = group.componentStoreIdent
        let groupIdent = group.localGroupIdent
        if isOptional:
            result.add quote do:
                let `groupIdent` = maybeGetPointer(`compStoreIdent`, `eid`.int32)
        else:
            result.add quote do:
                let `groupIdent` = getPointer(`compStoreIdent`, `members`[`i`])

proc optionalCompIdent(comp: ComponentDef): NimNode =
    ## The local variable to use for reading the value of an optional component
    ident("optional_comp_" & comp.name)

proc declareOptionalComps(codeGenInfo: CodeGenInfo, query: QueryDef): NimNode =
    ## Declares a variable containing the values for any optional components in a query
    result = newStmtList()
    for arg in query.args:
        if arg.kind == Optional:
            let group = codeGenInfo.compGroups[arg.component]
            let groupIndex = group[arg.component]
            let groupIdent = group.localGroupIdent
            let componentType = arg.component
            let compIdent = arg.component.optionalCompIdent

            if arg.isPointer:
                result.add quote do:
                    let `compIdent` = if isSome(`groupIdent`):
                        some(addr get(`groupIdent`)[`groupIndex`])
                    else:
                        none(ptr `componentType`)
            else:
                result.add quote do:
                    let `compIdent` = if isSome(`groupIdent`):
                        some(get(`groupIdent`)[`groupIndex`])
                    else:
                        none(`componentType`)



proc instantiateQueryTuple(codeGenInfo: CodeGenInfo, query: QueryDef): NimNode =
    ## Creates the code for instantiating the QueryItem tuple produced by a query
    result = nnkTupleConstr.newTree()
    for (i, arg) in query.args.toSeq.pairs:

        let group = codeGenInfo.compGroups[arg.component]
        let groupIndex = group[arg.component]
        let groupIdent = group.localGroupIdent
        let componentType = arg.component

        case arg.kind
        of Include:
            if arg.isPointer:
                result.add quote do: addr `groupIdent`[`groupIndex`]
            else:
                result.add quote do: `groupIdent`[`groupIndex`]
        of Exclude:
            result.add quote do: cast[Not[`componentType`]](0'i8)
        of Optional:
            result.add arg.component.optionalCompIdent

proc createQueryIterator(codeGenInfo: CodeGenInfo, queryName: string, query: QueryDef): NimNode =
    ## Creates the iterator needed to execute a query
    let procName = ident(queryName)
    let queryTupleType = query.args.asTupleType
    let queryStorageName = queryName.queryStorageIdent
    let compStoreVariables = codeGenInfo.createCompStoreVariables(query)
    let optionalComps = codeGenInfo.declareOptionalComps(query)
    var instantiateTuple = codeGenInfo.instantiateQueryTuple(query)
    return quote:
        proc `procName`(): auto =
            return iterator(): QueryItem[`queryTupleType`] {.closure.} =
                for (`eid`, `members`) in values(`queryStorageName`):
                    `compStoreVariables`
                    `optionalComps`
                    yield (`eid`, `instantiateTuple`)

proc createEmptyQuery(codeGenInfo: CodeGenInfo, queryName: string, query: QueryDef): NimNode =
    ## Create a query proc that always returns an empty iterator
    let procName = ident(queryName)
    let queryTupleType = query.args.asTupleType
    return quote:
        proc `procName`(): auto =
            return iterator(): QueryItem[`queryTupleType`] {.closure.} =
                discard

proc createQueries*(codeGenInfo: CodeGenInfo): NimNode =
    ## Creates the storage blocks and iterators for all the queries
    result = newStmtList()

    for (name, query) in codeGenInfo.queries:
        if codeGenInfo.canQueryExecute(query):
            result.add(codeGenInfo.createQueryStorageInstance(name, query))
            result.add(codeGenInfo.createQueryIterator(name, query))
        else:
            result.add(codeGenInfo.createEmptyQuery(name, query))
