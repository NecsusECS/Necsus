import entity, atomics, query

type

    World*[C: enum, D: object, Q: object] = object
        ## Contains the data describing the entire world
        entities*: seq[EntityMetadata[C]]
        components*: D
        queries*: Q
        nextEntityId: int

    Spawn*[C: tuple] = concept s
        ## Describes a type that is able to create new entities
        s.spawn(C) is EntityId

proc createEntity*[C, D, Q](world: var World[C, D, Q]): EntityId =
    ## Create a new entity in the given world
    result = EntityId(world.nextEntityId.atomicInc)

proc associateComponent*[C, D, Q, T](
    world: var World[C, D, Q],
    entityId: EntityId,
    componentFlag: C,
    componentSeq: var seq[T],
    componentValue: sink T
) =
    ## Associates a component
    discard

