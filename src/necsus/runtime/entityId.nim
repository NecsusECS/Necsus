import std/[hashes, bitops, strformat]

type
    EntityId* = distinct uint
        ## Identity of an entity

const GENERATION_BITS = 16

const ID_BITS = sizeof(EntityId) * 8 - GENERATION_BITS

const GENERATION_MASK = high(EntityId).uint shl ID_BITS

const ID_MASK = high(EntityId).uint shr GENERATION_BITS

proc `==`*(a, b: EntityId): bool =
    ## Compare two entities
    a.uint == b.uint

proc toInt*(entityId: EntityId): uint {.inline.} =
    bitand(uint(entityId), ID_MASK)

proc hash*(entityId: EntityId): Hash =
    Hash(entityId.toInt * 7)

proc generation(entityId: EntityId): uint {.inline.} =
    ## Returns the current generation of this entity
    bitand(uint(entityId), GENERATION_MASK).shr(ID_BITS)

proc incGen*(entityId: EntityId): EntityId =
    ## Increments the generation of an entity
    let newgen = (entityId.generation + 1).shl(ID_BITS)
    return EntityId(bitor(newgen, entityId.toInt))

proc `$`*(entityId: EntityId): string =
    ## Stringify an EntityId
    fmt"EntityId({entityId.generation}:{entityId.toInt})"
