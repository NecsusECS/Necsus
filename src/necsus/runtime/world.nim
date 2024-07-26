import entityId, ../util/blockstore

type
    ArchetypeId* = distinct BiggestInt

    EntityIndex* = object
        entityId*: EntityId
        archetype*: ArchetypeId
        archetypeIndex*: uint

    NewEntity* = distinct Entry[EntityIndex]

    World* = distinct BlockStore[EntityIndex]
        ## Contains the data describing the entire world

proc newWorld*(initialSize: SomeInteger): World = World(newBlockStore[EntityIndex](initialSize))
    ## Creates a new world

proc entityIndex(world: var World): var BlockStore[EntityIndex] {.inline.} = BlockStore[EntityIndex](world)

proc entityIndex(world: World): BlockStore[EntityIndex] {.inline.} = BlockStore[EntityIndex](world)

proc newEntity*(world: var World): NewEntity =
    ## Constructs a new entity and invokes
    let entity = world.entityIndex.reserve
    entity.value.entityId = EntityId(entity.index)
    return NewEntity(entity)

proc entityId*(newEntity: NewEntity): EntityId =
    ## Returns the entity ID of a newly created entity
    EntityId(Entry[EntityIndex](newEntity).index)

proc setArchetypeDetails*(newEntity: NewEntity, archetype: ArchetypeId, index: uint) =
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
