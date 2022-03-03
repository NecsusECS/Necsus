import entityId, entityMetadata, atomics, query, macros, entitySet, deques, ../util/openAddrTable

type

    World*[C: enum] = ref object
        ## Contains the data describing the entire world
        entities: OpenAddrTable[EntityId, EntityMetadata[C]]
        deleted*: EntitySet
        nextEntityId: int
        recycleEntityIds: Deque[EntityId]

proc newWorld*[C](initialSize: int): World[C] =
    ## Creates a new world
    World[C](
        entities: newOpenAddrTable[EntityId, EntityMetadata[C]](initialSize),
        deleted: newEntitySet(),
        nextEntityId: 0,
        recycleEntityIds: initDeque[EntityId]()
    )

proc associateComponents*[C](world: var World[C], entity: EntityId, components: set[C]): set[C] =
    ## Associates a given set of entities with a component
    world.entities[entity].incl(components)
    result = world.entities[entity].components

proc detachComponents*[C](world: var World[C], entity: EntityId, components: set[C]) =
    ## Associates a given set of entities with a component
    world.entities[entity].excl(components)

proc createEntity*[C](world: var World[C], initialComponents: set[C]): EntityId =
    ## Create a new entity in the given world
    if world.recycleEntityIds.len > 0:
        result = world.recycleEntityIds.popFirst
    else:
        result = EntityId(world.nextEntityId.atomicInc - 1)
    world.entities[result] = newEntityMetadata[C](initialComponents)
    # echo "Spawning ", result

proc getComponents*[C](world: var World[C], entityId: EntityId): set[C] =
    ## Returns all the set components for an entity
    world.entities[result].components

proc deleteEntity*[C](world: var World[C], entityId: EntityId) =
    world.deleted += entityId

proc deleteComponents*[C, T](world: World[C], components: var OpenAddrTable[EntityId, T]) =
    ## Removes deleted entities from a component table
    for entityId in world.deleted.items:
        components.del entityId

proc clearDeletedEntities*[C](world: var World[C]) =
    ## Resets the list of deleted entities
    for entity in world.deleted.items:
        world.entities.del(entity)
        world.recycleEntityIds.addLast entity
    world.deleted.clear()
