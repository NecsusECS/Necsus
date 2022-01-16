import entity, atomics, query, macros, entitySet, deques

type

    World*[C: enum, D: object, Q: object] = ref object
        ## Contains the data describing the entire world
        entities: seq[EntityMetadata[C]]
        components*: D
        queries*: Q
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

proc newWorld*[C, D, Q](initialSize: int, components: sink D, queries: sink Q): World[C, D, Q] =
    ## Creates a new world
    World[C, D, Q](
        entities: newSeq[EntityMetadata[C]](initialSize),
        components: components,
        queries: queries,
        deleted: newEntitySet(),
        nextEntityId: 0,
        recycleEntityIds: initDeque[EntityId]()
    )

proc createEntity*[C, D, Q](world: var World[C, D, Q]): EntityId =
    ## Create a new entity in the given world
    if world.recycleEntityIds.len > 0:
        result = world.recycleEntityIds.popFirst
    else:
        result = EntityId(world.nextEntityId.atomicInc - 1)
        assert(
            int(result) < world.entities.len,
            "Trying to spawn an entity (" & $result & ") beyond the max entity size: " & $world.entities.len
        )
    # echo "Spawning ", result

proc deleteEntity*[C, D, Q](world: var World[C, D, Q], entityId: EntityId) =
    world.deleted += entityId

proc evaluateEntityForQuery*[C, D, Q](
    world: World[C, D, Q],
    entityId: EntityId,
    query: var QueryMembers[C],
    queryName: string
) =
    ## Adds an entity to a query, if it has the necessary components
    if query.evaluate(world.entities[int(entityId)].components):
        query += entityId
        # echo entityId, ": Adding to query ", queryName

proc associateComponent*[C, D, Q, T](
    world: var World[C, D, Q],
    entityId: EntityId,
    componentFlag: C,
    componentSeq: var seq[T],
    componentValue: T
) =
    ## Associates a component
    # echo entityId, ": Adding component ", componentFlag
    incl(world.entities[int(entityId)].components, componentFlag)
    componentSeq[int(entityId)] = componentValue

proc clearDeletedEntities*[C, D, Q](world: var World[C, D, Q]) =
    ## Resets the list of deleted entities
    for entity in world.deleted.items:
        world.recycleEntityIds.addLast entity
    world.deleted.clear()
