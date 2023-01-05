import entityId, threading/atomics

type
    World*[Archs: enum] = object
        ## Contains the data describing the entire world
        entityIds: Atomic[int32]

proc newWorld*[Archs](initialSize: SomeInteger): World[Archs] =
    ## Creates a new world
    discard

proc `=copy`*[Archs](target: var World[Archs], source: World[Archs]) {.error.}

proc nextEntityId*[Archs](world: var World[Archs]): EntityId =
    ## Returns a new entity ID
    EntityId(world.entityIds.fetchAdd(1))
