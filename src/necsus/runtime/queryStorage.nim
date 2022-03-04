import queryFilter, entitySet, ../util/packedIntTable, entityId

type
    QueryStorage*[C: enum, M: tuple] {.byref.} = object
        ## Storage container for query data
        filter: QueryFilter[C]
        members: PackedIntTable[M]
        deleted: EntitySet

proc newQueryStorage*[C, M](initialSize: int, filter: QueryFilter[C]): QueryStorage[C, M] =
    ## Creates a storage container for query data
    QueryStorage[C, M](filter: filter, members: newPackedIntTable[M](initialSize), deleted: newEntitySet())

proc addToQuery*[C, M](storage: var QueryStorage[C, M], entityId: EntityId, componentRefs: sink M) =
    ## Registers an entity with this query
    storage.members[entityId.int32] = componentRefs
    storage.deleted -= entityId

proc removeFromQuery*[C, M](storage: var QueryStorage[C, M], entityId: EntityId) =
    ## Removes an entity from this query
    storage.deleted += entityId

proc updateEntity*[C, M](storage: var QueryStorage[C, M], entityId: EntityId, components: set[C]): bool =
    ## Evaluates an entity against this query. Returns true if the entity needs to be added to this query
    let shouldBeInQuery = storage.filter.evaluate(components)
    let isInQuery = (entityId.int32 in storage.members) and (entityId notin storage.deleted)
    if isInQuery and not shouldBeInQuery:
        storage.removeFromQuery(entityId)
    return shouldBeInQuery and not isInQuery

iterator values*[C, M](storage: var QueryStorage[C, M]): (EntityId, M) =
    ## Yields the component pointers in a storage object
    for (eid, components) in storage.members.pairs:
        let entity = EntityId(eid)
        if entity notin storage.deleted:
            yield (entity, components)

proc finalizeDeletes*[C, M](query: var QueryStorage[C, M]) =
    ## Removes any entities that are pending deletion from this query
    for entityId in items(query.deleted):
        query.members.del(entityId.int32)
    query.deleted.clear()