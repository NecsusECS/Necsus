import macros, options, tables, sequtils
import worldEnum, codeGenInfo, archetype, commonVars, systemGen, tickGen, parse
import ../runtime/[world, archetypeStore]

proc fields(genInfo: CodeGenInfo): seq[(NimNode, NimNode)] =
    ## Produces a list of all fields to attach to the state object
    let archetypeEnum = genInfo.archetypeEnum.ident

    result.add (worldIdent, nnkBracketExpr.newTree(bindSym"World", archetypeEnum))
    result.add (thisTime, ident"float")
    result.add (startTime, ident"float")

    for archetype in genInfo.archetypes:
        let storageType = archetype.asStorageTuple
        let typ = nnkBracketExpr.newTree(bindSym("ArchetypeStore"), archetypeEnum, storageType)
        result.add (archetype.ident, typ)

    for (name, typ) in genInfo.worldFields:
        result.add (name.ident, typ)


proc createAppStateType*(genInfo: CodeGenInfo): NimNode =
    ## Creates a type definition that captures the state of the app
    var fields = nnkRecList.newTree()
    for (fieldName, fieldTyp) in items(genInfo.fields):
        fields.add nnkIdentDefs.newTree(fieldName, fieldTyp, newEmptyNode())

    return nnkTypeSection.newTree(
        nnkTypeDef.newTree(
            genInfo.appStateStruct,
            newEmptyNode(),
            nnkObjectTy.newTree(newEmptyNode(), newEmptyNode(), fields)
        ),
        nnkTypeDef.newTree(
            genInfo.appStateTypeName,
            newEmptyNode(),
            nnkRefTy.newTree(genInfo.appStateStruct)
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
    let startups = genInfo.callSystems(genInfo.systems.filterIt(it.phase == StartupPhase))
    let beforeLoop = genInfo.generateForHook(GenerateHook.BeforeLoop)

    let initBody = quote:
        var `appStateIdent` = new(`appStateType`)
        let `confIdent` = `createConfig`
        `appStateIdent`.world = newWorld[`archetypeEnum`](`confIdent`.entitySize)
        `archetypeDefs`
        `earlyInit`
        `stdInit`
        `lateInit`
        `startups`
        `beforeLoop`
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

proc createAppStateDestructor*(genInfo: CodeGenInfo): NimNode =
    ## Creates the instance of the app state object
    let appStateType = genInfo.appStateStruct
    let destroy = "=destroy".ident
    let teardowns = genInfo.callSystems(genInfo.systems.filterIt(it.phase == TeardownPhase))

    let destroys = newStmtList()

    for (name, _) in items(genInfo.fields):
        destroys.add quote do:
            `destroy`(`appStateIdent`.`name`)

    return quote:
        proc `destroy`*(`appStateIdent`: var `appStateType`) =
            `teardowns`
            `destroys`
            `appStateIdent`.`worldIdent`.`destroy`()