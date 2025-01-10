import entityId, ../util/blockstore, std/deques

type
    ArchetypeId* = distinct BiggestInt

    EntityIndex* = object
        entityId*: EntityId
        archetype*: ArchetypeId
        archetypeIndex*: uint

    NewEntity* = distinct ptr EntityIndex

    World* = object
        ## Contains the data describing the entire world
        nextEntityId: uint
        entityIds: Deque[EntityId]
        index: seq[EntityIndex]

proc newWorld*(initialSize: SomeInteger): World =
    ## Creates a new world
    World(entityIds: initDeque[EntityId](initialSize div 10), index: newSeq[EntityIndex](initialSize))

proc getNewEntityId*(world: var World): EntityId {.inline.} =
    if world.entityIds.len > 0:
        result = world.entityIds.popFirst().incGen
    else:
        result = EntityId(world.nextEntityId)
        inc world.nextEntityId

proc newEntity*(world: var World): NewEntity =
    ## Constructs a new entity and invokes
    let eid = world.getNewEntityId()
    let entry = addr world.index[eid.toInt]
    entry.entityId = eid
    return NewEntity(entry)

proc entityId*(newEntity: NewEntity): EntityId =
    ## Returns the entity ID of a newly created entity
    (ptr EntityIndex)(newEntity).entityId

proc setArchetypeDetails*(entry: NewEntity, archetype: ArchetypeId, index: uint) =
    ## Stores the archetype details about an entity
    let entry = (ptr EntityIndex)(entry)
    entry.archetype = archetype
    entry.archetypeIndex = index

proc `[]`*(world: World, entityId: EntityId): ptr EntityIndex =
    ## Look up entity information based on an entity ID
    unsafeAddr world.index[entityId.toInt]

proc del*(world: var World, entityId: EntityId): EntityIndex =
    ## Deletes an entity and returns the archetype and index that also needs to be deleted
    result = world.index[entityId.toInt]
    world.index[entityId.toInt] = default(EntityIndex)
    world.entityIds.addLast(entityId)
