import macros, componentDef, componentSet, sequtils, codeGenInfo
import ../runtime/packedIntTable

proc createComponentEnum*(components: ComponentSet): NimNode =
    ## Creates an enum with an item for every available component
    var componentList = toSeq(components).mapIt(it.name.ident)
    if componentList.len == 0:
        componentList.add ident("Dummy")
    result = newEnum(components.enumSymbol, componentList, public = false, pure = true)

proc createComponentInstances*(genInfo: CodeGenInfo): NimNode =
    ## Creates the variables for component storage
    result = newStmtList()
    for component in genInfo.components:
        let storageIdent = component.componentStoreIdent
        result.add quote do:
            var `storageIdent` = newPackedIntTable[`component`](`confIdent`.componentSize)

proc createConfig*(genInfo: CodeGenInfo): NimNode =
    nnkLetSection.newTree(nnkIdentDefs.newTree(`confIdent`, newEmptyNode(), genInfo.config))

proc createWorldInstance*(genInfo: CodeGenInfo): NimNode =
    let componentEnum = genInfo.components.enumSymbol
    result = quote:
        var `worldIdent` = newWorld[`componentEnum`](`confIdent`.entitySize)
