import macros, sequtils, options
import componentDef, componentEnum, codeGenInfo, directiveSet, monoDirective, grouper, codeGenInfo
import ../util/packedIntTable, ../runtime/world

proc createComponentEnum*(components: ComponentEnum): NimNode =
    ## Creates an enum with an item for every available component
    var componentList = toSeq(components).mapIt(it.name.ident)
    if componentList.len == 0:
        componentList.add ident("Dummy")
    result = newEnum(components.enumSymbol, componentList, public = false, pure = true)

proc createComponentInstances*(genInfo: CodeGenInfo): NimNode =
    ## Creates the variables for component storage
    result = newStmtList()
    for group in genInfo.compGroups:
        let storageIdent = group.componentStoreIdent
        let storageType = group.asStorageTuple
        result.add quote do:
            var `storageIdent` = newPackedIntTable[`storageType`](`confIdent`.componentSize)

proc createConfig*(genInfo: CodeGenInfo): NimNode =
    nnkLetSection.newTree(nnkIdentDefs.newTree(`confIdent`, newEmptyNode(), genInfo.config))

proc createWorldInstance*(genInfo: CodeGenInfo): NimNode =
    let componentEnum = genInfo.components.enumSymbol
    result = quote:
        var `worldIdent` = newWorld[`componentEnum`](`confIdent`.entitySize)

proc createAppReturn*(genInfo: CodeGenInfo): NimNode =
    if genInfo.app.returns.isSome:
        let returns: SharedDef = genInfo.app.returns.get()
        let sharedVarIdent = genInfo.shared.nameOf(returns).ident
        return quote:
            return get(`sharedVarIdent`)
    else:
        return newEmptyNode()
