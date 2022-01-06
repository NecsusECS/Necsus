import macros, componentDef, componentSet

proc createComponentEnum*(components: ComponentSet): NimNode =
    ## Creates an enum with an item for every available component
    let enumType = nnkEnumTy.newTree(newEmptyNode())

    for component in components:
        enumType.add(component.ident)

    result = nnkTypeSection.newTree(
        nnkTypeDef.newTree(
            nnkPragmaExpr.newTree(
                components.symbol,
                nnkPragma.newTree(ident("pure"))),
            newEmptyNode(),
            enumType))
