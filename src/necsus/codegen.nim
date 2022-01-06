import macros, componentDef, componentSet

proc createComponentEnum*(components: ComponentSet): NimNode =
    ## Creates an enum with an item for every available component
    let enumType = nnkEnumTy.newTree(newEmptyNode())

    for component in components:
        enumType.add(component.ident)

    let enumName = components.enumSymbol

    result = quote:
        type `enumName` {.pure.} = `enumType`

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
