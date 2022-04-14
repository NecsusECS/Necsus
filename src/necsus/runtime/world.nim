import entityId, entityMetadata, atomics, query, macros, entitySet, deques, ../util/[fixedSizeTable, sharedVector]

type

    World*[C: enum, Q: enum, G: enum] = ref object
        ## Contains the data describing the entire world
        ## [C] is the enum type for each component
        ## [Q] is the enum type for each query
        ## [G] is the enum type for each component group
        entities: SharedVector[EntityMetadata[C, Q, G]]
        deleted*: EntitySet
        nextEntityId: int
        recycleEntityIds: Deque[EntityId]

proc newWorld*[C, Q, G](initialSize: SomeInteger): World[C, Q, G] =
    ## Creates a new world
    World[C, Q, G](
        entities: newSharedVector[EntityMetadata[C, Q, G]](initialSize.uint),
        deleted: newEntitySet(),
        nextEntityId: 0,
        recycleEntityIds: initDeque[EntityId]()
    )

template `[]`[T](vector: var SharedVector[T], eid: EntityId): untyped =
    mget(vector, eid.uint)

template `[]=`[T](vector: var SharedVector[T], eid: EntityId, value: sink T) =
    vector[eid.uint] = value

proc associateComponents*[C, Q, G](world: var World[C, Q, G], entity: EntityId, components: set[C]): set[C] =
    ## Associates a given set of entities with a component
    world.entities[entity].incl(components)
    result = world.entities[entity].components

proc detachComponents*[C, Q, G](world: var World[C, Q, G], entity: EntityId, components: set[C]) =
    ## Associates a given set of entities with a component
    world.entities[entity].excl(components)

proc createEntity*[C, Q, G](world: var World[C, Q, G], initialComponents: sink set[C]): EntityId =
    ## Create a new entity in the given world
    if world.recycleEntityIds.len > 0:
        result = world.recycleEntityIds.popFirst
    else:
        result = EntityId(world.nextEntityId.atomicInc - 1)
    world.entities[result].initEntityMetadata(initialComponents)
    # echo "Spawning ", result

proc metadata*[C, Q, G](world: ptr World[C, Q, G], entityId: EntityId): var EntityMetadata[C, Q, G] =
    ## Returns the metadata for an entity
    world.entities[entityId]

proc getComponents*[C, Q, G](world: var World[C, Q, G], entityId: EntityId): set[C] =
    ## Returns all the set components for an entity
    world.entities[result].components

proc deleteEntity*[C, Q, G](world: var World[C, Q, G], entityId: EntityId) =
    world.deleted += entityId

proc deleteComponents*[C, Q, G, T](world: World[C, Q, G], components: var FixedSizeTable[EntityId, T]) =
    ## Removes deleted entities from a component table
    for entityId in world.deleted.items:
        components.del entityId

proc clearDeletedEntities*[C, Q, G](world: var World[C, Q, G]) =
    ## Resets the list of deleted entities
    for entity in world.deleted.items:
        world.recycleEntityIds.addLast entity
    world.deleted.clear()
