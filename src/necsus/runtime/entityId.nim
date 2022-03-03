import hashes

type
    EntityId* = distinct int32
        ## Identity of an entity

proc `$`*(entityId: EntityId): string =
    ## Stringify an EntityId
    "EntityId(" & $int(entityId) & ")"

proc hash*(entityId: EntityId): Hash = int(entityId) * 7

proc `==`*(a, b: EntityId): bool {.borrow.}
