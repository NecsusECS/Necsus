import macros, componentDef, componentSet, sequtils, codeGenInfo, math
import ../runtime/packedIntTable

proc createComponentEnum*(components: ComponentSet): NimNode =
    ## Creates an enum with an item for every available component
    var componentList = toSeq(components).mapIt(it.ident)
    if componentList.len == 0:
        componentList.add ident("Dummy")
    result = newEnum(components.enumSymbol, componentList, public = false, pure = true)

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
    let tableType: NimNode = bindSym("PackedIntTable")
    result = newObject(
        components.objSymbol,
        components.toSeq.mapIt((it.ident, nnkBracketExpr.newTree(tableType, it.ident)))
    )

proc construct(
    typeName: NimNode,
    properties: openarray[tuple[name: string, expression: NimNode]]
): NimNode =
    ## Creates an instance of a type
    result = nnkObjConstr.newTree(typeName)
    for (name, expression) in properties:
        result.add(nnkExprColonExpr.newTree(ident(name), expression))

proc createComponentInstance*(genInfo: CodeGenInfo): NimNode =
    ## Creates the object for instantiating the component storage

    let componentObj = genInfo.components.objSymbol
    let componentInstance = construct(
        componentObj,
        genInfo.components.toSeq.map do (pair: auto) -> (string, NimNode):
            let componentType = pair.ident
            let call = quote: newPackedIntTable[`componentType`](ceilDiv(`initialSizeIdent`, 3))
            (pair.name, call)
    )

    result = quote:
        var `componentsIdent` = `componentInstance`

proc createWorldInstance*(
    initialSize: NimNode,
    components: ComponentSet
): NimNode =
    let componentEnum = components.enumSymbol
    result = quote:
        let `initialSizeIdent` = `initialSize`
        var `worldIdent` = newWorld[`componentEnum`](`initialSize`)

proc createDeleteProc*(): NimNode =
    ## Generates all the procs for updating entities
    let entity = ident("entity")
    result = quote do:
        proc `deleteProc`(`entity`: EntityId) =
            `worldIdent`.deleteEntity(`entity`)
