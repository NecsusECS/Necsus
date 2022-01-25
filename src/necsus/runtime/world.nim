import entity, atomics, query, macros, entitySet, deques, packedIntTable

type

    World*[C: enum] = ref object
        ## Contains the data describing the entire world
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
        deleted: newEntitySet(),
        nextEntityId: 0,
        recycleEntityIds: initDeque[EntityId]()
    )

proc createEntity*[C](world: var World[C]): EntityId =
    ## Create a new entity in the given world
    if world.recycleEntityIds.len > 0:
        result = world.recycleEntityIds.popFirst
    else:
        result = EntityId(world.nextEntityId.atomicInc - 1)
    # echo "Spawning ", result

proc deleteEntity*[C](world: var World[C], entityId: EntityId) =
    world.deleted += entityId

proc deleteComponents*[C, T](world: World[C], components: var PackedIntTable[T]) =
    ## Removes deleted entities from a component table
    for entityId in world.deleted.items:
        components.del entityId.int32

proc clearDeletedEntities*[C](world: var World[C]) =
    ## Resets the list of deleted entities
    for entity in world.deleted.items:
        world.recycleEntityIds.addLast entity
    world.deleted.clear()
