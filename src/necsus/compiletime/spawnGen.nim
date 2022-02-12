import tupleDirective, directiveSet, codeGenInfo, macros, sequtils, componentDef, queryGen, sets
import ../runtime/[packedIntTable, query]

let comps {.compileTime.} = ident("comps")

proc localIdent(component: ComponentDef): NimNode =
    ## The variable name to use for local references to a component
    ident("comp_" & component.name)

proc storeComponents(
    codeGenInfo: CodeGenInfo,
    entityId: NimNode,
    components: openarray[ComponentDef]
): NimNode =
    # Create code that will store the component values
    result = newStmtList()
    for (i, component) in components.pairs:
        let ident = component.localIdent
        let componentIdent = component.componentStoreIdent
        result.add quote do:
            let `ident` = setAndRef(`componentIdent`, `entityId`.int32, `comps`[`i`])

proc createLocalComponentTuple(query: QueryDef): NimNode =
    ## Creates a tuple constructor for instantiating local references to components
    result = nnkTupleConstr.newTree()
    for arg in query.args:
        case arg.kind
        of Include: result.add(arg.component.localIdent)
        of Exclude: discard
        of Optional: discard

proc registerSpawnComponents(
    codeGenInfo: CodeGenInfo,
    entityId: NimNode,
    spawn: SpawnDef
): NimNode =
    # Create code to register these components with the queries
    result = newStmtList()
    for query in codeGenInfo.queries.containing(spawn.toSeq):
        let queryIdent = codeGenInfo.queries.nameOf(query).queryStorageIdent
        let componentTuple = query.createLocalComponentTuple()
        result.add quote do:
            addToQuery(`queryIdent`, `entityId`, `componentTuple`)

proc createSpawnProc(codeGenInfo: CodeGenInfo, name: string, spawn: SpawnDef): NimNode =
    ## Creates a proc for spawning a new entity
    let procName = ident(name)
    let localComps = ident("localComps")
    let componentTuple = spawn.args.toSeq.asTupleType
    let store = codeGenInfo.storeComponents(ident("result"), spawn.toSeq)
    let register = codeGenInfo.registerSpawnComponents(ident("result"), spawn)
    let componentEnum = codeGenInfo.createComponentEnum(spawn.toSeq)
    result = quote:
        proc `procName`(`localComps`: sink `componentTuple`): EntityId =
            let `comps` = `localComps`
            result = `worldIdent`.createEntity(`componentEnum`)
            `store`
            `register`

proc createSpawns*(codeGenInfo: CodeGenInfo): NimNode =
    ## Generates all the procs for spawning new entities
    result = newStmtList()
    for (name, spawn) in codeGenInfo.spawns:
        result.add(codeGenInfo.createSpawnProc(name, spawn))

proc registerAttachComponents(
    codeGenInfo: CodeGenInfo,
    entityId: NimNode,
    componentEnum: NimNode,
    attach: AttachDef
): NimNode =
    # Create code to register these components with the queries
    result = newStmtList()
    let knownComponents = attach.toSeq.toHashSet
    for query in codeGenInfo.queries.mentioning(attach.toSeq):
        let queryIdent = codeGenInfo.queries.nameOf(query).queryStorageIdent
        let componentTuple = query.createLocalComponentTuple()

        # If there are components for this query that aren't explicitly being set with the current
        # update, then we need to go and fetch their current values
        let getExtraComponents = newStmtList()
        for component in query:
            if component notin knownComponents:
                let compIdent = component.localIdent
                let componentStorage = component.componentStoreIdent
                getExtraComponents.add quote do:
                    let `compIdent` = getRef[`component`](`componentStorage`, `entityId`.int32)

        result.add quote do:
            if `queryIdent`.updateEntity(`entityId`, `componentEnum`):
                `getExtraComponents`
                addToQuery(`queryIdent`, `entityId`, `componentTuple`)

proc createAttachProc(codeGenInfo: CodeGenInfo, name: string, attach: AttachDef): NimNode =
    ## Generates a proc to update components for an entity
    let procName = ident(name)
    let entityId = ident("entityId")
    let allComponents = ident("allComponents")
    let componentTuple = attach.args.toSeq.asTupleType
    let store = codeGenInfo.storeComponents(entityId, attach.toSeq)
    let register = codeGenInfo.registerAttachComponents(entityId, allComponents, attach)
    let componentEnum = codeGenInfo.createComponentEnum(attach.toSeq)
    result = quote:
        proc `procName`(`entityId`: EntityId, `comps`: `componentTuple`) =
            let `allComponents` = associateComponents(`worldIdent`, `entityId`, `componentEnum`)
            `store`
            `register`

proc createAttaches*(codeGenInfo: CodeGenInfo): NimNode =
    ## Generates all the procs for updating entities
    result = newStmtList()
    for (name, attach) in codeGenInfo.attaches:
        result.add(codeGenInfo.createAttachProc(name, attach))
