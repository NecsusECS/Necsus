import macros, sequtils, options, tables
import worldEnum, codeGenInfo, directiveSet, monoDirective, codeGenInfo, archetype, commonVars, tools
import ../runtime/[world, archetypeStore]

proc createArchetypeInstances*(genInfo: CodeGenInfo): NimNode =
    ## Creates variables for storing archetypes
    result = newStmtList()
    let archetypeEnum = genInfo.archetypeEnum.ident
    for archetype in genInfo.archetypes:
        let ident = archetype.ident
        let storageType = archetype.asStorageTuple
        let archetypeRef = genInfo.archetypeEnum.ident(archetype)
        result.add quote do:
            var `ident` = newArchetypeStore[`archetypeEnum`, `storageType`](`archetypeRef`, `confIdent`.componentSize)

proc createConfig*(genInfo: CodeGenInfo): NimNode =
    nnkLetSection.newTree(nnkIdentDefs.newTree(`confIdent`, newEmptyNode(), genInfo.config))

proc createWorldInstance*(genInfo: CodeGenInfo): NimNode =
    let archetypeEnum = genInfo.archetypeEnum.ident
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

proc createDeleteProc*(genInfo: CodeGenInfo): NimNode =
    ## Generates all the procs for updating entities
    let archetypeEnum = genInfo.archetypeEnum.ident
    let entity = ident("entity")
    let entityIndex = ident("entityIndex")

    let cases = genInfo.createArchetypeCase(newDotExpr(entityIndex, ident("archetype"))) do (fromArch: auto) -> auto:
        let archIdent = fromArch.ident
        quote:
            del(`archIdent`, `entityIndex`.archetypeIndex)

    result = quote do:
        proc `deleteProc`(`entity`: EntityId) {.used.} =
            let `entityIndex` = del[`archetypeEnum`](`worldIdent`, `entity`)
            `cases`
