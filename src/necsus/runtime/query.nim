import entityId, options, ../util/blockstore

type
  QueryItem*[Comps: tuple] = tuple[entityId: EntityId, components: Comps]
    ## An individual value yielded by a query. Where `Comps` is a tuple of the components to fetch in
    ## this query

  QueryNext*[Comps: tuple] = proc(
    appStatePtr: pointer,
    state: var uint,
    iter: var BlockIter,
    eid: var EntityId,
    slot: var Comps,
  ): bool {.gcsafe, raises: [], nimcall.}

  QueryGetLen = proc(appState: pointer): uint {.gcsafe, raises: [], nimcall.}

  RawQuery*[Comps] = ref object
    ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
    ## the components to fetch in this query.
    appState: pointer
    getLen: QueryGetLen
    getNext: QueryNext[Comps]

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

proc asFullQuery*[Comps](rawQuery: RawQuery[Comps]): FullQuery[Comps] =
  FullQuery[Comps](rawQuery)

proc asQuery*[Comps](rawQuery: RawQuery[Comps]): Query[Comps] =
  Query[Comps](rawQuery)

proc newQuery*[Comps: tuple](
    appState: pointer, getLen: QueryGetLen, getNext: QueryNext[Comps]
): RawQuery[Comps] =
  RawQuery[Comps](appState: appState, getLen: getLen, getNext: getNext)

iterator pairs*[Comps: tuple](query: FullQuery[Comps]): QueryItem[Comps] =
  ## Iterates through the entities in a query
  let raw = RawQuery[Comps](query)
  var state: uint
  var iter: BlockIter
  var eid: EntityId
  var slot: Comps
  while raw.getNext(raw.appState, state, iter, eid, slot):
    yield (eid, slot)

iterator items*[Comps: tuple](query: AnyQuery[Comps]): Comps =
  ## Iterates through the entities in a query
  let raw = RawQuery[Comps](query)
  var state: uint
  var iter: BlockIter
  var eid: EntityId
  var slot: Comps
  while raw.getNext(raw.appState, state, iter, eid, slot):
    yield slot

proc len*[Comps: tuple](query: AnyQuery[Comps]): uint {.gcsafe, raises: [].} =
  ## Returns the number of entities in this query
  let rawQuery = RawQuery[Comps](query)
  return rawQuery.getLen(rawQuery.appState)

proc single*[Comps: tuple](query: AnyQuery[Comps]): Option[Comps] =
  ## Returns a single element from a query
  for comps in query:
    return some(comps)
