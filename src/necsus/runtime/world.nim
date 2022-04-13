import entityId, entityMetadata, atomics, query, macros, entitySet, deques, ../util/[fixedSizeTable, sharedVector]

type

    World*[C: enum, Q: enum] = ref object
        ## Contains the data describing the entire world
        entities: SharedVector[EntityMetadata[C, Q]]
        deleted*: EntitySet
        nextEntityId: int
        recycleEntityIds: Deque[EntityId]

proc newWorld*[C, Q](initialSize: SomeInteger): World[C, Q] =
    ## Creates a new world
    World[C, Q](
        entities: newSharedVector[EntityMetadata[C, Q]](initialSize.uint),
        deleted: newEntitySet(),
        nextEntityId: 0,
        recycleEntityIds: initDeque[EntityId]()
    )

template `[]`[T](vector: var SharedVector[T], eid: EntityId): untyped =
    mget(vector, eid.uint)

template `[]=`[T](vector: var SharedVector[T], eid: EntityId, value: sink T) =
    vector[eid.uint] = value

proc associateComponents*[C, Q](world: var World[C, Q], entity: EntityId, components: set[C]): set[C] =
    ## Associates a given set of entities with a component
    world.entities[entity].incl(components)
    result = world.entities[entity].components

proc detachComponents*[C, Q](world: var World[C, Q], entity: EntityId, components: set[C]) =
    ## Associates a given set of entities with a component
    world.entities[entity].excl(components)

proc createEntity*[C, Q](world: var World[C, Q], initialComponents: set[C]): EntityId =
    ## Create a new entity in the given world
    if world.recycleEntityIds.len > 0:
        result = world.recycleEntityIds.popFirst
    else:
        result = EntityId(world.nextEntityId.atomicInc - 1)
    world.entities[result] = newEntityMetadata[C, Q](initialComponents)
    # echo "Spawning ", result

proc getComponents*[C, Q](world: var World[C, Q], entityId: EntityId): set[C] =
    ## Returns all the set components for an entity
    world.entities[result].components

proc deleteEntity*[C, Q](world: var World[C, Q], entityId: EntityId) =
    world.deleted += entityId

proc deleteComponents*[C, Q, T](world: World[C, Q], components: var FixedSizeTable[EntityId, T]) =
    ## Removes deleted entities from a component table
    for entityId in world.deleted.items:
        components.del entityId

proc clearDeletedEntities*[C, Q](world: var World[C, Q]) =
    ## Resets the list of deleted entities
    for entity in world.deleted.items:
        world.recycleEntityIds.addLast entity
    world.deleted.clear()
