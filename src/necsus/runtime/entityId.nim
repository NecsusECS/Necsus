import hashes

type
    EntityId* = distinct int32
        ## Identity of an entity

proc `$`*(entityId: EntityId): string =
    ## Stringify an EntityId
    "EntityId(" & $int(entityId) & ")"

proc `==`*(a, b: EntityId): bool =
    ## Compare two entities
    a.int32 == b.int32

proc hash*(entityId: EntityId): Hash =
    Hash(entityId.uint * 7)
