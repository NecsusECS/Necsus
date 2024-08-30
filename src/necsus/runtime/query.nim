import entityId, options

type
    QueryItem*[Comps: tuple] = tuple[entityId: EntityId, components: Comps]
        ## An individual value yielded by a query. Where `Comps` is a tuple of the components to fetch in
        ## this query

    QueryIterator*[Comps: tuple] = iterator(appState: pointer, slot: var Comps): EntityId {.gcsafe, raises: [].}

    QueryIteratorBuilder[Comps: tuple] = proc(): QueryIterator[Comps] {.gcsafe, raises: [], fastcall.}

    QueryGetLen = proc(appState: pointer): uint {.gcsafe, raises: [], fastcall.}

    RawQuery*[Comps] = ref object
        ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
        ## the components to fetch in this query.
        appState: pointer
        getLen: QueryGetLen
        getIterator: QueryIteratorBuilder[Comps]

    Query*[Comps: tuple] = distinct RawQuery[Comps]
        ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
        ## the components to fetch in this query. Does not provide access to the entity ID

    FullQuery*[Comps: tuple] = distinct RawQuery[Comps]
        ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
        ## the components to fetch in this query. Provides access to the EntityId

    AnyQuery*[Comps: tuple] = Query[Comps] | FullQuery[Comps]

    Not*[Comps] = distinct int8
        ## A query flag that indicates a component should be excluded from a query. Where `Comps` is
        ## the single component that should be excluded.

proc newQuery*[Comps: tuple](
    appState: pointer,
    getLen: QueryGetLen,
    getIterator: QueryIteratorBuilder[Comps]
): RawQuery[Comps] {.inline.} =
    RawQuery[Comps](appState: appState, getLen: getLen, getIterator: getIterator)

iterator pairs*[Comps: tuple](query: FullQuery[Comps]): QueryItem[Comps] =
    ## Iterates through the entities in a query
    let raw = RawQuery[Comps](query)
    var output: Comps
    let iter = raw.getIterator()
    for eid in iter(raw.appState, output):
        yield (eid, output)

iterator items*[Comps: tuple](query: AnyQuery[Comps]): Comps =
    ## Iterates through the entities in a query
    let raw = RawQuery[Comps](query)
    var output: Comps
    let iter = raw.getIterator()
    for _ in iter(raw.appState, output):
        yield output

proc len*[Comps: tuple](query: AnyQuery[Comps]): uint {.gcsafe, raises: [].} =
    ## Returns the number of entities in this query
    let rawQuery = RawQuery[Comps](query)
    return rawQuery.getLen(rawQuery.appState)

proc single*[Comps: tuple](query: AnyQuery[Comps]): Option[Comps] =
    ## Returns a single element from a query
    for comps in query:
        return some(comps)
