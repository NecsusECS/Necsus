import entityId, options, archetypeStore

type
    QueryItem*[Comps: tuple] = tuple[entityId: EntityId, components: Comps]
        ## An individual value yielded by a query. Where `Comps` is a tuple of the components to fetch in
        ## this query

    QueryIterator* = object
        ## An iterator over a query
        continuationIdx*: BiggestInt
        iter*: ArchetypeIter

    NextIterState* = enum DoneIter, ActiveIter, IncrementIter

    NextEntityProc*[Comps: tuple] = proc(
        iter: var QueryIterator, appStatePtr: pointer, eid: var EntityId, slot: var Comps
    ): NextIterState {.gcsafe, raises: [], fastcall.}
        ## Returns the next row in a query

    RawQuery* = object
        ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
        ## the components to fetch in this query.
        appState: pointer
        getLen: proc(appState: pointer): uint {.gcsafe, raises: [], fastcall.}
        nextEntity: pointer # Pointer to a NextEntityProc[Comps]

    RawQueryPtr = ptr RawQuery

    Query*[Comps: tuple] = distinct RawQueryPtr
        ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
        ## the components to fetch in this query. Does not provide access to the entity ID

    FullQuery*[Comps: tuple] = distinct RawQueryPtr
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
): RawQuery {.inline.} =
    RawQuery(appState: appState, getLen: getLen, nextEntity: nextEntity)

proc isFirst*(iter: QueryIterator): bool = iter.continuationIdx == 0 and iter.iter.isFirst

proc next*[Comps: tuple](
    store: ArchetypeStore[Comps],
    iter: var QueryIterator,
    eid: var EntityId,
    state: var NextIterState
): ptr Comps =
    ## Returns the next value for an interator
    let row = store.next(iter.iter)
    if row == nil:
        state = IncrementIter
    else:
        eid = row.entityId
        state = ActiveIter
        return addr row.components

iterator pairs*[Comps: tuple](query: FullQuery[Comps]): QueryItem[Comps] =
    ## Iterates through the entities in a query
    let rawQuery = RawQueryPtr(query)
    var iter: QueryIterator
    var slot: Comps
    var eid: EntityId
    let nextEntity = cast[NextEntityProc[Comps]](rawQuery.nextEntity)
    while true:
        case nextEntity(iter, rawQuery.appState, eid, slot)
        of ActiveIter:
            yield (entityId: eid, components: slot)
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
    let rawQuery = RawQueryPtr(query)
    return rawQuery.getLen(rawQuery.appState)

proc single*[Comps: tuple](query: AnyQuery[Comps]): Option[Comps] =
    ## Returns a single element from a query
    for comps in query:
        return some(comps)
