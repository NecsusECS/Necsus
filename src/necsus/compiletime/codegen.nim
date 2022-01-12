import macros, componentDef, componentSet, sequtils, directive, directiveSet, parse

proc createComponentEnum*(components: ComponentSet): NimNode =
    ## Creates an enum with an item for every available component
    result = newEnum(
        components.enumSymbol,
        toSeq(components).mapIt(it.ident),
        public = false,
        pure = true
    )

proc bracket(name: string, bracketed: NimNode): NimNode =
    ## Creates a bracketed expression
    nnkBracketExpr.newTree(ident(name), bracketed)

proc seqType(innerType: NimNode): NimNode =
    ## Creates a type wrapped in a seq
    bracket("seq", innerType)

proc newObject(
    name: NimNode,
    props: openarray[tuple[propName: NimNode, propType: NimNode]]
): NimNode =
    ## Defines an object with a set of properties
    let propNodes = nnkRecList.newTree()

    for (propName, propType) in props:
        propNodes.add(nnkIdentDefs.newTree(propName, propType, newEmptyNode()))

    let obj = nnkObjectTy.newTree(newEmptyNode(), newEmptyNode(), propNodes)

    result = quote:
        type `name` = `obj`

proc createComponentObj*(components: ComponentSet): NimNode =
    ## Defines an object for storing component data
    result = newObject(
        components.objSymbol,
        components.toSeq.mapIt((it.ident, seqType(it.ident)))
    )

proc createQueryObj*(
    components: ComponentSet,
    queries: DirectiveSet[QueryDef]
): NimNode =
    ## Defines a type for holding all possible queries
    let queryType = bracket("QueryMembers", components.enumSymbol)
    result = newObject(
        ident(queries.symbol),
        queries.toSeq.mapIt((propName: ident(it.name), propType: queryType))
    )

proc construct(
    typeName: NimNode,
    properties: openarray[tuple[name: string, expression: NimNode]]
): NimNode =
    ## Creates an instance of a type
    result = nnkObjConstr.newTree(typeName)
    for (name, expression) in properties:
        result.add(nnkExprColonExpr.newTree(ident(name), expression))

proc ident(components: ComponentSet, component: ComponentDef): NimNode =
    nnkDotExpr.newTree(components.enumSymbol, component.ident)

proc createQueryMembersInstance(
    query: QueryDef,
    components: ComponentSet
): NimNode =
    ## Creates code to instantiate a QueryMembers instance
    let componentEnum = components.enumSymbol
    let componentList = nnkCurly.newTree(toSeq(query).mapIt(components.ident(it)))
    result = quote:
        newQueryMembers[`componentEnum`](filterMatching[`componentEnum`](`componentList`))

proc createWorldInstance*(
    initialSize: BiggestInt,
    components: ComponentSet,
    queries: DirectiveSet[QueryDef]
): NimNode =
    let componentEnum = components.enumSymbol
    let componentObj = components.objSymbol
    let queryObj = ident(queries.symbol)
    let world = ident("world")
    let initialSizeIdent = ident("initialSize")

    let componentInstance = construct(
        componentObj,
        components.toSeq.map do (pair: auto) -> auto:
        (pair.name, newCall(bracket("newSeq", pair.ident), initialSizeIdent))
    )

    let queryInstance = construct(
        queryObj,
        toSeq(queries).mapIt((it.name, createQueryMembersInstance(it.value, components)))
    )

    result = quote:
        let `initialSizeIdent` = `initialSize`
        var `world` = World[`componentEnum`, `componentObj`, `queryObj`](
            entities: newSeq[EntityMetadata[`componentEnum`]](`initialSizeIdent`),
            components: `componentInstance`,
            queries: `queryInstance`
        )

proc asTupleType(components: seq[ComponentDef]): NimNode =
    ## Creates a tuple type from a list of components
    nnkTupleConstr.newTree(components.mapIt(it.ident))

proc createQueryVars*(components: ComponentSet, queries: DirectiveSet[QueryDef]): NimNode =
    result = newStmtList()

    let componentEnum = components.enumSymbol

    for (name, query) in queries:
        let varName = ident(name)

        let tupleType = toSeq(query).asTupleType

        let entityVar = ident("entityId")

        let tupleConstruction = nnkTupleConstr.newTree()
        for component in query:
            let componentIdent = component.ident
            tupleConstruction.add(
                block: quote: world.components.`componentIdent`[`entityVar`]
            )

        result.add quote do:
            let `varName` = newQuery[`componentEnum`, `tupleType`](
                world.queries.`varName`,
                proc (`entityVar`: EntityId): `tupleType` = `tupleConstruction`
            )

proc associateComponentsWithEntity(
    components: seq[ComponentDef],
    allComponents: ComponentSet,
    entityId: NimNode
): NimNode =
    ## Generates code to associate an entity with all applicable components
    result = newStmtList()
    for (idx, component) in components.pairs:
        let componentIdent = component.ident
        let enumIdent = allComponents.ident(component)
        result.add quote do:
            associateComponent(world, `entityId`, `enumIdent`, world.components.`componentIdent`, comps[`idx`])

proc evaluateQueries(
    components: seq[ComponentDef],
    queries: DirectiveSet[QueryDef],
    entityId: NimNode
): NimNode =
    ## Generates code to evaluate an entity against the appropriate queries
    result = newStmtList()
    for (name, _) in queries.containing(components):
        let ident = ident(name)
        result.add quote do:
            evaluateEntityForQuery(world, `entityId`, world.queries.`ident`, `name`)

proc createSpawnFunc*(
    components: ComponentSet,
    spawns: DirectiveSet[SpawnDef],
    queries: DirectiveSet[QueryDef]
): NimNode =
    ## Generates all the procs for spawning new entities
    result = newStmtList()
    for (name, spawn) in spawns:

        let spawnProcName = ident(name)
        let componentTuple = toSeq(spawn).asTupleType
        let componentsIdent = ident("comps")

        let associateComponents = spawn.toSeq.associateComponentsWithEntity(components, ident("result"))
        let evaluateQueries = spawn.toSeq.evaluateQueries(queries, ident("result"))

        result.add quote do:
            proc `spawnProcName`(`componentsIdent`: `componentTuple`): EntityId =
                result = world.createEntity()
                `associateComponents`
                `evaluateQueries`

proc createUpdateProcs*(
    components: ComponentSet,
    updates: DirectiveSet[UpdateDef],
    queries: DirectiveSet[QueryDef]
): NimNode =
    ## Generates all the procs for updating entities
    result = newStmtList()
    for (name, update) in updates:

        let updateProcName = ident(name)
        let componentTuple = toSeq(update).asTupleType
        let componentsIdent = ident("comps")
        let entityIdent = ident("entity")

        let associateComponents = update.toSeq.associateComponentsWithEntity(components, entityIdent)
        let evaluateQueries = update.toSeq.evaluateQueries(queries, entityIdent)

        result.add quote do:
            proc `updateProcName`(`entityIdent`: EntityId, `componentsIdent`: `componentTuple`) =
                `associateComponents`
                `evaluateQueries`

proc callSystems*(
    systems: openarray[ParsedSystem],
    components: ComponentSet,
    spawns: DirectiveSet[SpawnDef],
    queries: DirectiveSet[QueryDef],
    updates: DirectiveSet[UpdateDef]
): NimNode =
    result = newStmtList()
    for system in systems:
        let props = system.args.toSeq.map do (arg: SystemArg) -> NimNode:
            case arg.kind
            of SystemArgKind.Spawn:
                ident(spawns.nameOf(arg.spawn))
            of SystemArgKind.Query:
                ident(queries.nameOf(arg.query))
            of SystemArgKind.Update:
                ident(updates.nameOf(arg.update))

        result.add(newCall(ident(system.symbol), props))

