import entityId

type
    EntityMetadata*[C: enum, Q: enum] {.byref.} = object
        ## General data about an entity
        components: set[C]
        queryIndexes: array[Q, tuple[isMember: bool, index: uint]]

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

proc isInQuery*[C, Q](metadata: var EntityMetadata[C, Q], query: Q): bool =
    ## Returns whether this entity is a member of a specific query
    metadata.queryIndexes[query].isMember

proc setQueryIndex*[C, Q](metadata: var EntityMetadata[C, Q], query: Q, index: uint) =
    ## Marks this entity as a member of a specific query
    metadata.queryIndexes[query] = (true, index)

template removeQueryIndex*[C, Q](metadata: EntityMetadata[C, Q], query: Q, callback: untyped) =
    ## Removes this entity from membership in a specific query
    if metadata.queryIndexes[query].isMember:
        metadata.queryIndexes[query].isMember = false
        let index {.inject.} = metadata.queryIndexes[query].index
        callback
