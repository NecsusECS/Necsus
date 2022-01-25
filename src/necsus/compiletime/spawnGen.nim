import directive, directiveSet, codeGenInfo, macros, sequtils, componentDef, queryGen
import ../runtime/[packedIntTable, query]

let comps {.compileTime.} = ident("comps")

proc storeAndRegisterComponents(
    codeGenInfo: CodeGenInfo,
    entityId: NimNode,
    components: openarray[ComponentDef]
): NimNode =
    ## Generates code for updating an entity in both entity storage and queries
    result = newStmtList()

    # Create code that will allocate the components
    for (i, component) in components.pairs:
        let compIdent = ident("comp" & $component)
        result.add quote do:
            let `compIdent` = setAndRef(`componentsIdent`.`component`, `entityId`.int32, `comps`[`i`])

    # Create code to register these components with the queries
    for (name, query) in codeGenInfo.queries.containing(components):
        let queryIdent = name.queryStorageIdent
        let componentTuple = nnkTupleConstr.newTree(query.toSeq.mapIt(ident("comp" & $it)))
        result.add quote do:
            addToQuery(`queryIdent`, `entityId`, `componentTuple`)

proc createSpawnProc(codeGenInfo: CodeGenInfo, name: string, spawn: SpawnDef): NimNode =
    ## Creates a proc for spawning a new entity
    let procName = ident(name)
    let componentTuple = spawn.toSeq.asTupleType
    let updateComponents = codeGenInfo.storeAndRegisterComponents(ident("result"), spawn.toSeq)
    result = quote:
        proc `procName`(`comps`: `componentTuple`): EntityId =
            result = `worldIdent`.createEntity()
            `updateComponents`

proc createSpawns*(codeGenInfo: CodeGenInfo): NimNode =
    ## Generates all the procs for spawning new entities
    result = newStmtList()
    for (name, spawn) in codeGenInfo.spawns:
        result.add(codeGenInfo.createSpawnProc(name, spawn))

proc createUpdateProc(codeGenInfo: CodeGenInfo, name: string, update: UpdateDef): NimNode =
    ## Generates a proc to update components for an entity
    let procName = ident(name)
    let entityId = ident("entityId")
    let componentTuple = update.toSeq.asTupleType
    let updateComponents = codeGenInfo.storeAndRegisterComponents(entityId, update.toSeq)
    result = quote:
        proc `procName`(`entityId`: EntityId, `comps`: `componentTuple`) =
            `updateComponents`

proc createUpdates*(codeGenInfo: CodeGenInfo): NimNode =
    ## Generates all the procs for updating entities
    result = newStmtList()
    for (name, update) in codeGenInfo.updates:
        result.add(codeGenInfo.createUpdateProc(name, update))
