import entityId, ../util/blockstore

type
    ArchetypeId* = distinct BiggestInt

    EntityIndex* = object
        entityId*: EntityId
        archetype*: ArchetypeId
        archetypeIndex*: uint

    NewEntity* = distinct Entry[EntityIndex]

    World* = object
        ## Contains the data describing the entire world
        entityIndex: BlockStore[EntityIndex]

proc newWorld*(initialSize: SomeInteger): World =
    ## Creates a new world
    result.entityIndex = newBlockStore[EntityIndex](initialSize)

proc `=copy`*(target: var World, source: World) {.error.}

proc newEntity*(world: var World): NewEntity {.inline.} =
    ## Constructs a new entity and invokes
    let entity = world.entityIndex.reserve
    entity.value.entityId = EntityId(entity.index)
    return NewEntity(entity)

proc entityId*(newEntity: NewEntity): EntityId {.inline.} =
    ## Returns the entity ID of a newly created entity
    EntityId(Entry[EntityIndex](newEntity).index)

proc setArchetypeDetails*(newEntity: NewEntity, archetype: ArchetypeId, index: uint) {.inline.} =
    ## Stores the archetype details about an entity
    let entry = Entry[EntityIndex](newEntity)
    entry.value.archetype = archetype
    entry.value.archetypeIndex = index
    entry.commit

proc `[]`*(world: World, entityId: EntityId): ptr EntityIndex =
    ## Look up entity information based on an entity ID
    addr world.entityIndex[entityId.uint]

proc del*(world: var World, entityId: EntityId): EntityIndex =
    ## Deletes an entity and returns the archetype and index that also needs to be deleted
    result = world.entityIndex[entityId.uint]
    discard world.entityIndex.del(entityId.uint)
