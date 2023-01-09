import hashes

type
    EntityId* = distinct uint
        ## Identity of an entity

proc `$`*(entityId: EntityId): string =
    ## Stringify an EntityId
    "EntityId(" & $int(entityId) & ")"

proc `==`*(a, b: EntityId): bool =
    ## Compare two entities
    a.uint == b.uint

proc hash*(entityId: EntityId): Hash =
    Hash(entityId.uint * 7)

proc toInt*(entityId: EntityId): uint =
    entityId.uint
