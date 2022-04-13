import macros, sequtils, options
import worldEnum, codeGenInfo, directiveSet, monoDirective, grouper, codeGenInfo
import ../util/fixedSizeTable, ../runtime/[world, entityId]

proc createComponentInstances*(genInfo: CodeGenInfo): NimNode =
    ## Creates the variables for component storage
    result = newStmtList()
    for group in genInfo.compGroups:
        let storageIdent = group.componentStoreIdent
        let storageType = group.asStorageTuple
        result.add quote do:
            var `storageIdent` = newFixedSizeTable[EntityId, `storageType`](`confIdent`.componentSize)

proc createConfig*(genInfo: CodeGenInfo): NimNode =
    nnkLetSection.newTree(nnkIdentDefs.newTree(`confIdent`, newEmptyNode(), genInfo.config))

proc createWorldInstance*(genInfo: CodeGenInfo): NimNode =
    let componentEnum = genInfo.components.enumSymbol
    let queryEnum = genInfo.queryEnum.enumSymbol
    result = quote:
        var `worldIdent` = newWorld[`componentEnum`, `queryEnum`](`confIdent`.entitySize)

proc createAppReturn*(genInfo: CodeGenInfo): NimNode =
    if genInfo.app.returns.isSome:
        let returns: SharedDef = genInfo.app.returns.get()
        let sharedVarIdent = genInfo.shared.nameOf(returns).ident
        return quote:
            return get(`sharedVarIdent`)
    else:
        return newEmptyNode()
