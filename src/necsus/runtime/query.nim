import entitySet, entity, queryFilter, packedIntTable

type
    QueryItem*[T: tuple] = tuple[entityId: EntityId, components: T]
        ## An individual value yielded by a query

    Query*[T: tuple] = proc(): iterator(): QueryItem[T]
        ## Allows systems to query for entities with specific components

    QueryStorage*[C: enum, M: tuple] {.byref.} = object
        ## Storage container for query data
        filter: QueryFilter[C]
        members: PackedIntTable[M]
        deleted: EntitySet

proc newQueryStorage*[C, M](initialSize: int, deletedEntities: EntitySet, filter: QueryFilter[C]): QueryStorage[C, M] =
    ## Creates a storage container for query data
    QueryStorage[C, M](filter: filter, members: newPackedIntTable[M](initialSize), deleted: deletedEntities)

proc addToQuery*[C, M](storage: var QueryStorage[C, M], entityId: EntityId, componentRefs: sink M) =
    ## Registers an entity with this query
    storage.members[entityId.int32] = componentRefs
    assert(entityId.int32 in storage.members)

iterator items*[C, M](storage: QueryStorage[C, M]): (EntityId, M) =
    ## Yields the component pointers in a storage object
    for (eid, components) in storage.members.pairs:
        let entity = EntityId(eid)
        if entity notin storage.deleted:
            yield (entity, components)

iterator items*[T: tuple](query: Query[T]): QueryItem[T] =
    ## Iterates through the entities in a query
    let iter = query()
    for pair in iter(): yield pair

iterator components*[T: tuple](query: Query[T]): T =
    ## Iterates through the entities in a query
    for (_, components) in query.items: yield components

proc finalizeDeletes*[C, M](query: var QueryStorage[C, M]) =
    ## Removes any entities that are pending deletion from this query
    for entityId in items(query.deleted):
        query.members.del(entityId.int32)
