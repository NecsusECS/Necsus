import macros, componentDef, componentSet, sequtils, queryDef, directiveSet

proc createComponentEnum*(components: ComponentSet): NimNode =
    ## Creates an enum with an item for every available component
    result = newEnum(
        components.enumSymbol,
        toSeq(components).mapIt(it.ident),
        public = false,
        pure = true
    )

proc bracket(name: string, bracketed: NimNode): NimNode =
    ## Creates a bracketed expression
    nnkBracketExpr.newTree(ident(name), bracketed)

proc seqType(innerType: NimNode): NimNode =
    ## Creates a type wrapped in a seq
    bracket("seq", innerType)

proc newObject(
    name: NimNode,
    props: openarray[tuple[propName: NimNode, propType: NimNode]]
): NimNode =
    ## Defines an object with a set of properties
    let propNodes = nnkRecList.newTree()

    for (propName, propType) in props:
        propNodes.add(nnkIdentDefs.newTree(propName, propType, newEmptyNode()))

    let obj = nnkObjectTy.newTree(newEmptyNode(), newEmptyNode(), propNodes)

    result = quote:
        type `name` = `obj`

proc createComponentObj*(components: ComponentSet): NimNode =
    ## Defines an object for storing component data
    result = newObject(
        components.objSymbol,
        components.toSeq.mapIt((it.ident, seqType(it.ident)))
    )

proc createQueryObj*(
    components: ComponentSet,
    queries: DirectiveSet[QueryDef]
): NimNode =
    ## Defines a type for holding all possible queries
    let queryType = bracket("QueryMembers", components.enumSymbol)
    result = newObject(
        ident(queries.symbol),
        queries.toSeq.mapIt((propName: ident(it.name), propType: queryType))
    )

proc construct(
    typeName: NimNode,
    properties: openarray[tuple[name: string, expression: NimNode]]
): NimNode =
    ## Creates an instance of a type
    result = nnkObjConstr.newTree(typeName)
    for (name, expression) in properties:
        result.add(nnkExprColonExpr.newTree(ident(name), expression))

proc createQueryMembersInstance(
    query: QueryDef,
    components: ComponentSet
): NimNode =
    ## Creates code to instantiate a QueryMembers instance
    let componentEnum = components.enumSymbol
    let componentList = nnkCurly.newTree(
        toSeq(query).mapIt(nnkDotExpr.newTree(componentEnum, it.ident))
    )
    result = quote:
        newQueryMembers[`componentEnum`](filterMatching[`componentEnum`](`componentList`))

proc createWorldInstance*(
    components: ComponentSet,
    queries: DirectiveSet[QueryDef]
): NimNode =
    let componentEnum = components.enumSymbol
    let componentObj = components.objSymbol
    let queryObj = ident(queries.symbol)
    let world = ident("world")

    let componentInstance = construct(
        componentObj,
        toSeq(components).mapIt((it.name, newCall(bracket("newSeq", it.ident))))
    )

    let queryInstance = construct(
        queryObj,
        toSeq(queries).mapIt((it.name, createQueryMembersInstance(it.value, components)))
    )

    result = quote:
        let initialSize = 100
        var `world` = World[`componentEnum`, `componentObj`, `queryObj`](
            entities: newSeq[EntityMetadata[`componentEnum`]](initialSize),
            components: `componentInstance`,
            queries: `queryInstance`
        )

proc createQueryVars*(components: ComponentSet, queries: DirectiveSet[QueryDef]): NimNode =
    result = newStmtList()

    let componentEnum = components.enumSymbol

    for (name, query) in queries:
        let varName = ident(name)

        let tupleType = nnkTupleConstr.newTree(toSeq(query).mapIt(it.ident))

        let entityVar = ident("entityId")

        let tupleConstruction = nnkTupleConstr.newTree()
        for component in query:
            let componentIdent = component.ident
            tupleConstruction.add(
                block: quote: world.components.`componentIdent`[`entityVar`]
            )

        let queryVar = quote:
            let `varName` = newQuery[`componentEnum`, `tupleType`](
                world.queries.`varName`,
                proc (`entityVar`: EntityId): `tupleType` = `tupleConstruction`
            )

        result.add(queryVar)

