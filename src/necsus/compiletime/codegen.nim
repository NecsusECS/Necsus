import macros, sequtils, options, tables
import worldEnum, codeGenInfo, directiveSet, monoDirective, codeGenInfo, archetype
import ../util/fixedSizeTable, ../runtime/[world, archetypeStore]

proc createArchetypeInstances*(genInfo: CodeGenInfo): NimNode =
    ## Creates variables for storing archetypes
    result = newStmtList()
    for archetype in genInfo.archetypes:
        let ident = archetype.ident
        let storageType = archetype.asStorageTuple
        result.add quote do:
            var `ident` = newArchetypeStore[`storageType`](`confIdent`.componentSize)

proc createConfig*(genInfo: CodeGenInfo): NimNode =
    nnkLetSection.newTree(nnkIdentDefs.newTree(`confIdent`, newEmptyNode(), genInfo.config))

proc createWorldInstance*(genInfo: CodeGenInfo): NimNode =
    let archetypeEnum = genInfo.archetypeEnum.enumSymbol
    result = quote:
        var `worldIdent` = newWorld[`archetypeEnum`](`confIdent`.entitySize)

proc createAppReturn*(genInfo: CodeGenInfo): NimNode =
    if genInfo.app.returns.isSome:
        let returns: SharedDef = genInfo.app.returns.get()
        let sharedVarIdent = genInfo.shared.nameOf(returns).ident
        return quote:
            return get(`sharedVarIdent`)
    else:
        return newEmptyNode()
