import entityId, options

type
    QueryItem*[Comps: tuple] = tuple[entityId: EntityId, components: Comps]
        ## An individual value yielded by a query. Where `Comps` is a tuple of the components to fetch in
        ## this query

    QueryIterator*[Comps: tuple] = iterator(slot: var Comps): EntityId {.gcsafe, raises: [].}
        ## An iterator over a query

    RawQuery*[Comps: tuple] = object
        ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
        ## the components to fetch in this query.
        appState: pointer
        getLen: proc(appState: pointer): uint {.gcsafe, raises: [], fastcall.}
        getIterator: proc(appState: pointer): QueryIterator[Comps] {.gcsafe, raises: [], fastcall.}

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
    getIterator: proc(appState: pointer): QueryIterator[Comps] {.gcsafe, raises: [], fastcall.}
): RawQuery[Comps] =
    RawQuery[Comps](appState: appState, getLen: getLen, getIterator: getIterator)

iterator pairs*[Comps: tuple](query: FullQuery[Comps]): QueryItem[Comps] =
    ## Iterates through the entities in a query
    let rawQuery = RawQueryPtr[Comps](query)
    let iter = rawQuery.getIterator(rawQuery.appState)
    var slot: Comps
    for eid in iter(slot):
        yield (eid, slot)

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
