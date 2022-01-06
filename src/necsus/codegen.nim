import macros, componentDef, componentSet, sequtils

proc createComponentEnum*(components: ComponentSet): NimNode =
    ## Creates an enum with an item for every available component
    result = newEnum(
        components.enumSymbol,
        toSeq(components).mapIt(it.ident),
        public = false,
        pure = true
    )

proc createComponentObj*(components: ComponentSet): NimNode =
    ## Defines an object for storing component data
    let props = nnkRecList.newTree()

    for component in components:
        props.add(
            nnkIdentDefs.newTree(
                component.ident,
                nnkBracketExpr.newTree(ident("seq"), component.ident),
                newEmptyNode()))

    let obj = nnkObjectTy.newTree(newEmptyNode(), newEmptyNode(), props)

    let objName = components.objSymbol

    result = quote:
        type `objName` = `obj`
