import macros, sequtils, sets, tables
import tupleDirective, directiveSet, codeGenInfo, componentDef, queryGen, grouper
import ../runtime/[packedIntTable, query]

let comps {.compileTime.} = ident("comps")

proc localIdent(component: ComponentDef): NimNode =
    ## The variable name to use for local references to a component
    ident("comp_" & component.name)

proc localIdent(group: Group[ComponentDef]): NimNode =
    ## The variable name to use for local references to a group of components
    ident("comp_group_" & group.name)

proc storeComponents(codeGenInfo: CodeGenInfo, entityId: NimNode, directive: SpawnDef | AttachDef): NimNode =
    # Create code that will store the component values
    result = newStmtList()

    # Create a map of components and the index they represent from the input
    let componentMap = newTable(directive.toSeq.pairs.toSeq.mapIt((it[1], it[0])))

    for group in codeGenInfo.groups(directive):
        let groupIdent = group.localIdent
        let compStoreIdent = group.componentStoreIdent

        var storageTuple = nnkTupleConstr.newTree()
        for component in group:
            storageTuple.add(nnkBracketExpr.newTree(comps, newLit(componentMap[component])))

        result.add quote do:
            let `groupIdent` = setAndRef(`compStoreIdent`, `entityId`.int32, `storageTuple`)

proc createLocalComponentTuple(codeGenInfo: CodeGenInfo, query: QueryDef): NimNode =
    ## Creates a tuple constructor for instantiating local references to components
    nnkTupleConstr.newTree(codeGenInfo.queryGroups(query).toSeq.filterIt(not it.optional).mapIt(it.group.localIdent))

proc registerSpawnComponents(
    codeGenInfo: CodeGenInfo,
    entityId: NimNode,
    spawn: SpawnDef
): NimNode =
    # Create code to register these components with the queries
    result = newStmtList()
    for query in codeGenInfo.queries.containing(spawn.toSeq):
        let queryIdent = codeGenInfo.queries.nameOf(query).queryStorageIdent
        let componentTuple = codeGenInfo.createLocalComponentTuple(query)
        result.add quote do:
            addToQuery(`queryIdent`, `entityId`, `componentTuple`)

proc createSpawnProc(codeGenInfo: CodeGenInfo, name: string, spawn: SpawnDef): NimNode =
    ## Creates a proc for spawning a new entity
    let procName = ident(name)
    let localComps = ident("localComps")
    let componentTuple = spawn.args.toSeq.asTupleType
    let store = codeGenInfo.storeComponents(ident("result"), spawn)
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
        let componentTuple = codeGenInfo.createLocalComponentTuple(query)

        # If there are components for this query that aren't explicitly being set with the current
        # update, then we need to go and fetch their current values
        let getExtraComponents = newStmtList()
        for group in query.toSeq.filterIt(it notin knownComponents).mapIt(codeGenInfo.compGroups[it]).deduplicate():
            let compStore = group.componentStoreIdent
            let localIdent = group.localIdent
            getExtraComponents.add quote do:
                let `localIdent` = getRef(`compStore`, `entityId`.int32)

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
    let store = codeGenInfo.storeComponents(entityId, attach)
    let register = codeGenInfo.registerAttachComponents(entityId, allComponents, attach)
    let componentEnum = codeGenInfo.createComponentEnum(attach.toSeq)
    result = quote:
        proc `procName`(`entityId`: EntityId, `comps`: `componentTuple`) {.used.} =
            let `allComponents` {.used.} = associateComponents(`worldIdent`, `entityId`, `componentEnum`)
            `store`
            `register`

proc createAttaches*(codeGenInfo: CodeGenInfo): NimNode =
    ## Generates all the procs for updating entities
    result = newStmtList()
    for (name, attach) in codeGenInfo.attaches:
        result.add(codeGenInfo.createAttachProc(name, attach))
