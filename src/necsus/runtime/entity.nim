
type
    EntityId* = distinct int32
        ## Identity of an entity

    EntityMetadata*[C: enum] {.byref.} = object
        ## General data about an entity
        components: set[C]

proc `[]`*[T](s: openarray[T], id: EntityId): T =
    ## Allows indexing into an openarray by directly using an entity id
    s[int(id)]

proc `$`*(entityId: EntityId): string =
    ## Stringify an EntityId
    "EntityId(" & $int(entityId) & ")"

proc newEntityMetadata*[C](components: set[C]): EntityMetadata[C] =
    ## Constructor
    EntityMetadata[C](components: components)

proc incl*[C](metadata: var EntityMetadata[C], components: set[C]) =
    ## Adds components to entity metadata
    metadata.components.incl(components)

proc excl*[C](metadata: var EntityMetadata[C], components: set[C]) =
    ## Removes components to entity metadata
    metadata.components.excl(components)

proc components*[C](metadata: EntityMetadata[C]): set[C] =
    ## Return components in an entity
    metadata.components
