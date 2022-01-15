import entity, atomics, query, macros

type

    World*[C: enum, D: object, Q: object] = ref object
        ## Contains the data describing the entire world
        entities*: seq[EntityMetadata[C]]
        components*: D
        queries*: Q
        nextEntityId: int

    Spawn*[C: tuple] = proc(components: C): EntityId
        ## Describes a type that is able to create new entities

    Update*[C: tuple] = proc(entityId: EntityId, components: C)
        ## Describes a type that is able to update existing entities new entities

    TimeDelta* = float
        ## Tracks the amount of time since the last execution of a system

proc createEntity*[C, D, Q](world: var World[C, D, Q]): EntityId =
    ## Create a new entity in the given world
    result = EntityId(world.nextEntityId.atomicInc - 1)
    assert(
        int(result) < world.entities.len,
        "Trying to spawn an entity (" & $result & ") beyond the max entity size: " & $world.entities.len
    )
    # echo "Spawning ", result

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
