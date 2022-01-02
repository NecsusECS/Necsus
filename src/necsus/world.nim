import entity, atomics

type

    World*[C: enum, D: object] = object
        ## Contains the data describing the entire world
        entities*: seq[EntityMetadata[C]]
        components*: D
        nextEntityId: int

    Spawn*[C: tuple] = concept s
        ## Describes a type that is able to create new entities
        s.spawn(C) is EntityId

proc createEntity*[C: enum, D: object](world: var World[C, D]): EntityId =
    ## Create a new entity in the given world
    result = EntityId(world.nextEntityId.atomicInc)

proc associateComponent*[C: enum, D: object, T](
    world: var World[C, D],
    entityId: EntityId,
    componentFlag: C,
    componentSeq: var seq[T],
    componentValue: sink T
) =
    ## Associates a component
    discard

