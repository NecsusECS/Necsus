import macros, options, tables, sequtils
import worldEnum, codeGenInfo, archetype, commonVars, systemGen
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
            nnkRefTy.newTree(nnkObjectTy.newTree(newEmptyNode(), newEmptyNode(), fields))
        )
    )

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

proc createArchetypeState(genInfo: CodeGenInfo): NimNode =
    ## Creates variables for storing archetypes
    result = newStmtList()
    let archetypeEnum = genInfo.archetypeEnum.ident
    for archetype in genInfo.archetypes:
        let ident = archetype.ident
        let storageType = archetype.asStorageTuple
        let archetypeRef = genInfo.archetypeEnum.ident(archetype)
        result.add quote do:
            `appStateIdent`.`ident` =
                newArchetypeStore[`archetypeEnum`, `storageType`](`archetypeRef`, `confIdent`.componentSize)

proc createAppStateInit*(genInfo: CodeGenInfo): NimNode =
    ## Creates a proc for initializing the app state object
    let createConfig = genInfo.config
    let appStateType = genInfo.appStateTypeName
    let archetypeEnum = genInfo.archetypeEnum.ident
    let archetypeDefs = genInfo.createArchetypeState
    let earlyInit = genInfo.generateForHook(GenerateHook.Early)
    let stdInit = genInfo.generateForHook(GenerateHook.Standard)
    let lateInit = genInfo.generateForHook(GenerateHook.Late)

    let initBody = quote:
        var `appStateIdent` = new(`appStateType`)
        let `confIdent` = `createConfig`
        `appStateIdent`.world = newWorld[`archetypeEnum`](`confIdent`.entitySize)
        `archetypeDefs`
        `earlyInit`
        `stdInit`
        `lateInit`
        return `appStateIdent`

    let args = genInfo.app.inputs.mapIt(newIdentDefs(it.argName.ident, it.directive.argType))

    return newProc(
        name = genInfo.appStateInit,
        params = @[appStateType].concat(args),
        body = initBody
    )

proc createAppStateInstance*(genInfo: CodeGenInfo): NimNode =
    ## Creates the instance of the app state object
    let invoke = newCall(genInfo.appStateInit, genInfo.app.inputs.mapIt(it.argName.ident))
    return quote:
        var `appStateIdent` = `invoke`