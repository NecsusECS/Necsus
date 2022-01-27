import entity, atomics, query, macros, entitySet, deques, packedIntTable

type

    World*[C: enum] = ref object
        ## Contains the data describing the entire world
        entities: PackedIntTable[EntityMetadata[C]]
        deleted*: EntitySet
        nextEntityId: int
        recycleEntityIds: Deque[EntityId]

    Spawn*[C: tuple] = proc(components: C): EntityId
        ## Describes a type that is able to create new entities

    Update*[C: tuple] = proc(entityId: EntityId, components: C)
        ## Describes a type that is able to update existing entities new entities

    Delete* = proc(entityId: EntityId)
        ## Deletes an entity

    TimeDelta* = float
        ## Tracks the amount of time since the last execution of a system

proc newWorld*[C](initialSize: int): World[C] =
    ## Creates a new world
    World[C](
        entities: newPackedIntTable[EntityMetadata[C]](initialSize),
        deleted: newEntitySet(),
        nextEntityId: 0,
        recycleEntityIds: initDeque[EntityId]()
    )

proc associateComponents*[C](world: var World[C], entity: EntityId, components: set[C]): set[C] =
    ## Associates a given set of entities with a component
    world.entities[entity.int32].incl(components)
    return world.entities[entity.int32].components

proc createEntity*[C](world: var World[C], initialComponents: set[C]): EntityId =
    ## Create a new entity in the given world
    if world.recycleEntityIds.len > 0:
        result = world.recycleEntityIds.popFirst
    else:
        result = EntityId(world.nextEntityId.atomicInc - 1)
    world.entities[result.int32] = newEntityMetadata[C](initialComponents)
    # echo "Spawning ", result

proc getComponents*[C](world: var World[C], entityId: EntityId): set[C] =
    ## Returns all the set components for an entity
    world.entities[result.int32].components

proc deleteEntity*[C](world: var World[C], entityId: EntityId) =
    world.deleted += entityId

proc deleteComponents*[C, T](world: World[C], components: var PackedIntTable[T]) =
    ## Removes deleted entities from a component table
    for entityId in world.deleted.items:
        components.del entityId.int32

proc clearDeletedEntities*[C](world: var World[C]) =
    ## Resets the list of deleted entities
    for entity in world.deleted.items:
        world.entities.del(entity.int32)
        world.recycleEntityIds.addLast entity
    world.deleted.clear()
