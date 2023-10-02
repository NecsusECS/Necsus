import entityId, ../util/blockstore

type
    EntityIndex*[Archs: enum] = object
        entityId*: EntityId
        archetype*: Archs
        archetypeIndex*: uint

    NewEntity*[Archs: enum] = distinct Entry[EntityIndex[Archs]]

    World*[Archs: enum] = object
        ## Contains the data describing the entire world
        entityIndex: BlockStore[EntityIndex[Archs]]

proc newWorld*[Archs: enum](initialSize: SomeInteger): World[Archs] =
    ## Creates a new world
    result.entityIndex = newBlockStore[EntityIndex[Archs]](initialSize)

proc `=copy`*[Archs](target: var World[Archs], source: World[Archs]) {.error.}

proc newEntity*[Archs](world: var World[Archs]): NewEntity[Archs] {.inline.} =
    ## Constructs a new entity and invokes
    let entity = world.entityIndex.reserve
    entity.value.entityId = EntityId(entity.index)
    return NewEntity(entity)

proc entityId*[Archs](newEntity: NewEntity[Archs]): EntityId {.inline.} =
    ## Returns the entity ID of a newly created entity
    EntityId(Entry[EntityIndex[Archs]](newEntity).index)

proc setArchetypeDetails*[Archs](newEntity: NewEntity[Archs], archetype: Archs, index: uint) {.inline.} =
    ## Stores the archetype details about an entity
    let entry = Entry[EntityIndex[Archs]](newEntity)
    entry.value.archetype = archetype
    entry.value.archetypeIndex = index
    entry.commit

proc `[]`*[Archs: enum](world: World[Archs], entityId: EntityId): ptr EntityIndex[Archs] =
    ## Look up entity information based on an entity ID
    addr world.entityIndex[entityId.uint]

proc del*[Archs: enum](world: var World[Archs], entityId: EntityId): EntityIndex[Archs] =
    ## Deletes an entity and returns the archetype and index that also needs to be deleted
    result = world.entityIndex[entityId.uint]
    discard world.entityIndex.del(entityId.uint)
