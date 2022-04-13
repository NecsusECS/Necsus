import entityId

type
    EntityMetadata*[C: enum, Q: enum] {.byref.} = object
        ## General data about an entity
        components: set[C]

proc `[]`*[T](s: openarray[T], id: EntityId): T =
    ## Allows indexing into an openarray by directly using an entity id
    s[int(id)]

proc initEntityMetadata*[C, Q](metadata: var EntityMetadata[C, Q], components: set[C]) {.inline.} =
    ## Constructor
    metadata.components = components

proc incl*[C, Q](metadata: var EntityMetadata[C, Q], components: set[C]) =
    ## Adds components to entity metadata
    metadata.components.incl(components)

proc excl*[C, Q](metadata: var EntityMetadata[C, Q], components: set[C]) =
    ## Removes components to entity metadata
    metadata.components.excl(components)

proc components*[C, Q](metadata: EntityMetadata[C, Q]): set[C] =
    ## Return components in an entity
    metadata.components
