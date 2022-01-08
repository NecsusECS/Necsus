import macros, componentDef, componentSet, sequtils, queryDef

proc createComponentEnum*(components: ComponentSet): NimNode =
    ## Creates an enum with an item for every available component
    result = newEnum(
        components.enumSymbol,
        toSeq(components).mapIt(it.ident),
        public = false,
        pure = true
    )

proc seqType(innerType: NimNode): NimNode =
    ## Creates a type wrapped in a seq
    nnkBracketExpr.newTree(ident("seq"), innerType)

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

proc createQueryObj*(components: ComponentSet, queries: QuerySet): NimNode =
    ## Defines a type for holding all possible queries
    let queryType = nnkBracketExpr.newTree(
        ident("QueryMembers"),
        components.enumSymbol)
    result = newObject(
        ident(queries.objSymbol),
        queries.toSeq.mapIt((propName: ident(it.name), propType: queryType))
    )

