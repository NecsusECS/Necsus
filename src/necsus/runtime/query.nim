import entityId, options, archetypeStore

type
    QueryItem*[Comps: tuple] = tuple[entityId: EntityId, components: Comps]
        ## An individual value yielded by a query. Where `Comps` is a tuple of the components to fetch in
        ## this query

    QueryIterator* = object
        ## An iterator over a query
        continuationIdx*: uint16
        iter*: ArchetypeIter

    NextIterState* = enum DoneIter, ActiveIter, IncrementIter

    NextEntityProc*[Comps: tuple] = proc(
        iter: var QueryIterator, appStatePtr: pointer, slot: var QueryItem[Comps]
    ): NextIterState {.gcsafe, raises: [], fastcall.}
        ## Returns the next row in a query

    RawQuery*[Comps: tuple] = object
        ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
        ## the components to fetch in this query.
        appState: pointer
        getLen: proc(appState: pointer): uint {.gcsafe, raises: [], fastcall.}
        nextEntity: NextEntityProc[Comps]

    RawQueryPtr[Comps: tuple] = ptr RawQuery[Comps]

    Query*[Comps: tuple] = distinct RawQueryPtr[Comps]
        ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
        ## the components to fetch in this query. Does not provide access to the entity ID

    FullQuery*[Comps: tuple] = distinct RawQueryPtr[Comps]
        ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
        ## the components to fetch in this query. Provides access to the EntityId

    AnyQuery*[Comps: tuple] = Query[Comps] | FullQuery[Comps]

    Not*[Comps] = distinct int8
        ## A query flag that indicates a component should be excluded from a query. Where `Comps` is
        ## the single component that should be excluded.

proc newQuery*[Comps: tuple](
    appState: pointer,
    getLen: proc(appState: pointer): uint {.gcsafe, raises: [], fastcall.},
    nextEntity: NextEntityProc[Comps],
): RawQuery[Comps] {.inline.} =
    RawQuery[Comps](appState: appState, getLen: getLen, nextEntity: nextEntity)

iterator pairs*[Comps: tuple](query: FullQuery[Comps]): QueryItem[Comps] =
    ## Iterates through the entities in a query
    let rawQuery = RawQueryPtr[Comps](query)
    var iter: QueryIterator
    var slot: QueryItem[Comps]
    while true:
        let result = rawQuery.nextEntity(iter, rawQuery.appState, slot)
        case result
        of ActiveIter:
            yield slot
        of IncrementIter:
            iter.continuationIdx += 1
            iter.iter = default(ArchetypeIter)
        of DoneIter:
            break

iterator items*[Comps: tuple](query: AnyQuery[Comps]): Comps =
    ## Iterates through the entities in a query
    {.hint[ConvFromXtoItselfNotNeeded]:off.}
    for (_, components) in pairs(FullQuery[Comps](query)): yield components

proc len*[Comps: tuple](query: AnyQuery[Comps]): uint {.gcsafe, raises: [].} =
    ## Returns the number of entities in this query
    let rawQuery = RawQueryPtr[Comps](query)
    return rawQuery.getLen(rawQuery.appState)

proc single*[Comps: tuple](query: AnyQuery[Comps]): Option[Comps] =
    ## Returns a single element from a query
    for comps in query:
        return some(comps)
