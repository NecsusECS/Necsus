import queryFilter, entitySet, entityId, options, ../util/blockstore, world, entityMetadata

type
    QueryEntry*[M: tuple] = tuple[entityId: EntityId, data: M]
        ## An individually stored value in a query

    QueryStorage*[C: enum, Q: enum, M: tuple] {.byref.} = object
        ## Storage container for query data
        world: ptr World[C, Q]
        queryType: Q
        filter: QueryFilter[C]
        members: BlockStore[QueryEntry[M]]

proc newQueryStorage*[C, Q, M](
    queryType: Q,
    initialSize: int,
    filter: QueryFilter[C],
    world: ptr World[C, Q]
): QueryStorage[C, Q, M] =
    ## Creates a storage container for query data
    result.queryType = queryType
    result.filter = filter
    result.members = newBlockStore[QueryEntry[M]](initialSize)
    result.world = world

proc addToQuery*[C, Q, M](storage: var QueryStorage[C, Q, M], entityId: EntityId, componentRefs: sink M) =
    ## Registers an entity with this query
    let index = storage.members.push((entityId, componentRefs))
    storage.world.metadata(entityId).setQueryIndex(storage.queryType, index)

proc removeFromQuery*[C, Q, M](storage: var QueryStorage[C, Q, M], entityId: EntityId) =
    ## Removes an entity from this query
    storage.world.metadata(entityId).removeQueryIndex(storage.queryType):
        storage.members.del(index)

proc updateEntity*[C, Q, M](storage: var QueryStorage[C, Q, M], entityId: EntityId, components: set[C]): bool =
    ## Evaluates an entity against this query. Returns true if the entity needs to be added to this query
    let shouldBeInQuery = storage.filter.evaluate(components)
    let isInQuery = storage.world.metadata(entityId).isInQuery(storage.queryType)
    if isInQuery and not shouldBeInQuery:
        storage.removeFromQuery(entityId)
    return shouldBeInQuery and not isInQuery

iterator values*[C, Q, M](storage: var QueryStorage[C, Q, M]): QueryEntry[M] =
    ## Yields the component pointers in a storage object
    for entry in storage.members.items:
        yield entry
