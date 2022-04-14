import entityId

type
    EntityMetadata*[C: enum, Q: enum, G: enum] {.byref.} = object
        ## General data about an entity
        ## [C] is the enum type for each component
        ## [Q] is the enum type for each query
        ## [G] is the enum type for each component group
        components: set[C]
        queryIndexes: array[Q, tuple[isMember: bool, index: uint]]

proc `[]`*[T](s: openarray[T], id: EntityId): T =
    ## Allows indexing into an openarray by directly using an entity id
    s[int(id)]

proc initEntityMetadata*[C, Q, G](metadata: var EntityMetadata[C, Q, G], components: set[C]) {.inline.} =
    ## Constructor
    metadata.components = components

proc incl*[C, Q, G](metadata: var EntityMetadata[C, Q, G], components: set[C]) =
    ## Adds components to entity metadata
    metadata.components.incl(components)

proc excl*[C, Q, G](metadata: var EntityMetadata[C, Q, G], components: set[C]) =
    ## Removes components to entity metadata
    metadata.components.excl(components)

proc components*[C, Q, G](metadata: EntityMetadata[C, Q, G]): set[C] =
    ## Return components in an entity
    metadata.components

proc isInQuery*[C, Q, G](metadata: var EntityMetadata[C, Q, G], query: Q): bool =
    ## Returns whether this entity is a member of a specific query
    metadata.queryIndexes[query].isMember

proc setQueryIndex*[C, Q, G](metadata: var EntityMetadata[C, Q, G], query: Q, index: uint) =
    ## Marks this entity as a member of a specific query
    metadata.queryIndexes[query] = (true, index)

template removeQueryIndex*[C, Q, G](metadata: EntityMetadata[C, Q, G], query: Q, callback: untyped) =
    ## Removes this entity from membership in a specific query
    if metadata.queryIndexes[query].isMember:
        metadata.queryIndexes[query].isMember = false
        let index {.inject.} = metadata.queryIndexes[query].index
        callback
