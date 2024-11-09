import std/[macros, options, tables, sequtils, sets]
import tools, codeGenInfo, archetype, common, systemGen, converters
import tickGen, parse, eventGen, monoDirective
import ../runtime/[world, archetypeStore, necsusConf], ../util/profile

proc fields(genInfo: CodeGenInfo): seq[(NimNode, NimNode)] =
    ## Produces a list of all fields to attach to the state object
    result.add (confIdent, bindSym("NecsusConf"))
    result.add (worldIdent, bindSym("World"))
    result.add (thisTime, bindSym("BiggestFloat"))
    result.add (startTime, bindSym("BiggestFloat"))

    for system in genInfo.systems:
        if system.phase == IndirectEventCallback:
            let typ = nnkBracketExpr.newTree(bindSym("seq"), system.callbackSysType)
            result.add (system.callbackSysMailboxName, typ)

    for archetype in genInfo.archetypes:
        let storageType = archetype.asStorageTuple
        let typ = nnkBracketExpr.newTree(bindSym("ArchetypeStore"), storageType)
        result.add (archetype.ident, typ)

    for (name, typ) in genInfo.worldFields:
        result.add (name.ident, typ)

proc createAppStateType*(genInfo: CodeGenInfo): NimNode =
    ## Creates a type definition that captures the state of the app
    var fields = nnkRecList.newTree()
    for (fieldName, fieldTyp) in items(genInfo.fields):
        fields.add nnkIdentDefs.newTree(fieldName, fieldTyp, newEmptyNode())

    # Add in any instanced systems
    for system in genInfo.systems:
        if system.instanced.isSome:
            let (fieldName, fieldType) = system.instancedInfo().unsafeGet
            fields.add nnkIdentDefs.newTree(fieldName, fieldType, newEmptyNode())

    if profilingEnabled():
        var maxId = 0
        for system in genInfo.systems:
            maxId = max(maxId, system.id)
        fields.add(
            nnkIdentDefs.newTree(
                ident("profile"),
                nnkBracketExpr.newTree(ident("array"), newLit(maxId + 1), bindSym("Profiler")),
                newEmptyNode()
            )
        )

    let appType = genInfo.appStateTypeName
    let copy = ident("=copy")
    let a = ident("a")
    let b = ident("b")

    return newStmtList(
        nnkTypeSection.newTree(
            nnkTypeDef.newTree(
                genInfo.appStateTypeName,
                newEmptyNode(),
                nnkObjectTy.newTree(newEmptyNode(), newEmptyNode(), fields)
            )
        ),
        quote do:
            proc `copy`(`a`: var `appType`, `b`: `appType`) {.error.}
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
    for archetype in genInfo.archetypes:
        let ident = archetype.ident
        let storageType = archetype.asStorageTuple
        let archetypeRef = archetype.idSymbol

        let calculatedSize = archetype.calculateSize
        let size = if calculatedSize.isSome:
            calculatedSize.get
        else:
            quote: `appStateIdent`.config.componentSize

        result.add quote do:
            `appStateIdent`.`ident` = newArchetypeStore[`storageType`](`archetypeRef`, `size`)
            if `appStateIdent`.`confIdent`.eagerAlloc:
                ensureAlloced(`appStateIdent`.`ident`)

proc initProfilers(genInfo: CodeGenInfo): NimNode =
    result = newStmtList()
    if profilingEnabled():
        for system in genInfo.systems:
            let name = system.symbol.strVal
            let i = system.id
            result.add quote do:
                `appStateIdent`.profile[`i`].name = `name`

proc createAppStateInit*(genInfo: CodeGenInfo): NimNode =
    ## Creates a proc for initializing the app state object

    let initBody = if isFastCompileMode(fastInit):
        newStmtList()
    else:
        let createConfig = genInfo.config
        let stdInit = genInfo.generateForHook(GenerateHook.Standard)
        let lateInit = genInfo.generateForHook(GenerateHook.Late)
        let initializers = genInfo.initializeSystems()
        let startups = genInfo.callSystems({StartupPhase})
        let beforeLoop = genInfo.generateForHook(GenerateHook.BeforeLoop)
        let profilers = genInfo.initProfilers()
        let archetypeDefs = genInfo.createArchetypeState()

        quote:
            let `appStatePtr` {.used.} = addr `appStateIdent`
            `appStateIdent`.`confIdent` =  `createConfig`
            `appStateIdent`.`confIdent`.log("Beginning app initialization")
            `appStateIdent`.`worldIdent` = newWorld(`appStateIdent`.`confIdent`.entitySize)
            `appStateIdent`.`startTime` = `appStateIdent`.`confIdent`.getTime()
            `appStateIdent`.`confIdent`.log("Initializing archetypes")
            `archetypeDefs`
            `profilers`
            `appStateIdent`.`confIdent`.log("Beginning startup sys execution")
            `stdInit`
            `lateInit`
            `initializers`
            `startups`
            `beforeLoop`

    let args = genInfo.app.inputs.mapIt(newIdentDefs(it.argName.ident, it.directive.argType))

    return newStmtList(
        newProc(
            name = genInfo.appStateInit,
            params = @[
                newEmptyNode(),
                newIdentDefs(appStateIdent, nnkVarTy.newTree(genInfo.appStateTypeName))
            ].concat(args),
            body = initBody
        )
    )

proc createAppStateInstance*(genInfo: CodeGenInfo): NimNode =
    ## Creates the instance of the app state object
    let extraArgs = genInfo.app.inputs.mapIt(it.argName.ident)
    let invoke = newCall(genInfo.appStateInit, @[ appStateIdent ].concat(extraArgs))
    let appType = genInfo.appStateTypeName
    return quote:
        var `appStateIdent`: `appType`
        `invoke`

proc createAppStateDestructor*(genInfo: CodeGenInfo): NimNode =
    ## Creates the instance of the app state object
    let appStateType = genInfo.appStateTypeName
    let destroy = "=destroy".ident

    let destroys = newStmtList()

    if not isFastCompileMode(fastDestroy):
        destroys.add(genInfo.callSystems({TeardownPhase}))
        destroys.add(genInfo.destroySystems())

        for (name, _) in items(genInfo.fields):
            destroys.add quote do:
                `destroy`(`appStateIdent`.`name`)

    return quote:
        {.warning[Deprecated]:off, hint[XCannotRaiseY]:off.}
        proc `destroy`*(
            `appStateIdent`: var `appStateType`
        ) {.raises: [Exception], used.} =
            `destroys`

proc mailboxIndex(details: CodeGenInfo): Table[MonoDirective, seq[(ParsedSystem, NimNode)]] =
    ## Creates a table of all inboxes keyd on the type of message they receive
    result = initTable[MonoDirective, seq[(ParsedSystem, NimNode)]](64)
    for system in details.systems:
        for arg in system.allArgs:

            if arg.generator == inboxGenerator:
                result.mgetOrPut(arg.monoDir, newSeq[(ParsedSystem, NimNode)]())
                    .add((system, details.nameOf(arg).ident))

            elif arg.generator == outboxGenerator:
                # Store any outboxes to ensure the public send procs get created
                discard result.mgetOrPut(arg.monoDir, newSeq[(ParsedSystem, NimNode)]())

let event {.compileTime.} = ident("event")

proc genAddToInbox(
    details: CodeGenInfo, system: ParsedSystem,
    eventType, inboxIdent: NimNode,
    seen: var HashSet[string]
): NimNode =
    ## Generates code for adding an event to an inbox
    if inboxIdent.strVal notin seen:
        seen.incl(inboxIdent.strVal)
        let addStmt = quote: add[`eventType`](`appStateIdent`.`inboxIdent`, `event`)
        return addStmt.addActiveChecks(details, system.checks, EventCallback)
    else:
        return newStmtList()

proc createSendProcs*(details: CodeGenInfo): NimNode =
    ## Generates a set of procs needed to send messages
    result = newStmtList()
    let appStateType = details.appStateTypeName

    for directive, inboxes in details.mailboxIndex:
        let (internalName, externalName) = directive.sendEventProcName
        let eventType = directive.argType

        var body = newStmtList(
            emitEventTrace("Event ", directive.name, ": ", `event`)
        )

        var seen = initHashSet[string]()

        if not isFastCompileMode(fastEvents):
            for (system, inboxIdent) in inboxes:
                body.add details.genAddToInbox(system, eventType, inboxIdent, seen)

            for system in details.systems:
                case system.phase
                of EventCallback:
                    if eventType == system.callbackSysType:
                        body.add(details.invokeSystem(system, {EventCallback}, [ event ]))
                of IndirectEventCallback:
                    if eventType == system.callbackSysType:
                        body.add details.genAddToInbox(system, eventType, system.callbackSysMailboxName, seen)
                else:
                    discard

        if body.len == 0:
            body.add(nnkDiscardStmt.newTree(newEmptyNode()))

        result.add quote do:
            proc `internalName`(`appStateIdent`: pointer, `event`: `eventType`) {.used, fastcall.} =
                let `appStateIdent` {.used.} = cast[ptr `appStateType`](`appStateIdent`)
                `body`

            proc `externalName`(`appStateIdent`: var `appStateType`, `event`: `eventType`) {.used, fastcall.} =
                `internalName`(addr `appStateIdent`, `event`)

proc createConverterProcs*(details: CodeGenInfo): NimNode =
    ## Creates a list of procs for converting from one tuple type to another
    result = newStmtList()

    let ctx = details.newGenerateContext(Outside)
    for arg in details.allArgs:
        for convert in converters(ctx, arg):
            result.add(buildConverter(convert))

proc createArchetypeIdSyms*(details: CodeGenInfo): NimNode =
    result = newStmtList()
    for archetype in details.archetypes:
        result.add(archetype.archArchSymbolDef)
