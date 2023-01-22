import macros, options, tables
import worldEnum, codeGenInfo, archetype, commonVars, systemGen, nimNode
import ../runtime/[world, archetypeStore]

proc createAppStateType*(genInfo: CodeGenInfo): NimNode =
    ## Creates a type definition that captures the state of the app
    let archetypeEnum = genInfo.archetypeEnum.ident

    var fields = nnkRecList.newTree(
        nnkIdentDefs.newTree(worldIdent, nnkBracketExpr.newTree(bindSym("World"), archetypeEnum), newEmptyNode()),
        nnkIdentDefs.newTree(thisTime, "float".ident, newEmptyNode()),
        nnkIdentDefs.newTree(startTime, "float".ident, newEmptyNode()),
    )

    for archetype in genInfo.archetypes:
        let storageType = archetype.asStorageTuple
        fields.add nnkIdentDefs.newTree(
            archetype.ident,
            nnkBracketExpr.newTree(bindSym("ArchetypeStore"), archetypeEnum, storageType),
            newEmptyNode()
        )

    for (name, typ) in genInfo.worldFields:
        fields.add nnkIdentDefs.newTree(name.ident, typ, newEmptyNode())

    return nnkTypeSection.newTree(
        nnkTypeDef.newTree(
            genInfo.appStateTypeName,
            newEmptyNode(),
            nnkObjectTy.newTree(newEmptyNode(), newEmptyNode(), fields)
        )
    )

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

proc createAppReturn*(genInfo: CodeGenInfo, errorLocation: NimNode): NimNode =
    ## Creates the return statement for the app
    if genInfo.app.returns.isSome:
        let returns = genInfo.app.returns.get()
        for generator, directives in genInfo.directives:
            if generator.kind == DirectiveKind.Mono:
                let genReturn = generator.systemReturn(directives, returns)
                if genReturn.isSome:
                    return nnkReturnStmt.newTree(genReturn.get)
        error("No directives were able to supply a return value", errorLocation)
    return newEmptyNode()
