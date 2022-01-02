type
    EntityId* = distinct int
        ## Identity of an entity

    EntityMetadata*[C: enum] = object
        ## General data about an entity
        components: set[C]

proc `[]`*[T](s: openarray[T], id: EntityId): T =
    ## Allows indexing into an openarray by directly using an entity id
    s[int(id)]

proc `$`*(entityId: EntityId): string =
    ## Stringify an EntityId
    "EntityId(" & $int(entityId) & ")"
