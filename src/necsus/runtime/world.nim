import entityId, ../util/blockstore

type
    EntityIndex*[Archs: enum] = object
        archetype*: Archs
        archetypeIndex*: uint

    World*[Archs: enum] = object
        ## Contains the data describing the entire world
        entityIndex: BlockStore[EntityIndex[Archs]]

proc newWorld*[Archs: enum](initialSize: SomeInteger): World[Archs] =
    ## Creates a new world
    result.entityIndex = newBlockStore[EntityIndex[Archs]](initialSize)

proc `=copy`*[Archs](target: var World[Archs], source: World[Archs]) {.error.}

proc newEntity*[Archs](
    world: var World[Archs],
    archetype: Archs,
    saveComponents: proc (entityId: EntityId): uint
): EntityId {.inline.} =
    ## Constructs a new entity and invokes
    let eid = reserve(world.entityIndex) do (index: uint, value: var EntityIndex[Archs]) -> void:
        value.archetype = archetype
        value.archetypeIndex = saveComponents(EntityId(index))
    return EntityId(eid)

proc `[]`*[Archs: enum](world: World[Archs], entityId: EntityId): lent EntityIndex[Archs] =
    ## Look up entity information based on an entity ID
    world.entityIndex[entityId.uint]
