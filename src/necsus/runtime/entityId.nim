type
    EntityId* = distinct int32
        ## Identity of an entity

proc `$`*(entityId: EntityId): string =
    ## Stringify an EntityId
    "EntityId(" & $int(entityId) & ")"
