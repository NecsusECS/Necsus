import entityId, options, archetypeStore

type
  QueryItem*[Comps: tuple] = tuple[entityId: EntityId, components: Comps]
    ## An individual value yielded by a query. Where `Comps` is a tuple of the components to fetch in
    ## this query

  QueryConvert*[Comps: tuple] = proc(
    input: pointer, adding: pointer, output: var Comps
  ): bool {.gcsafe, raises: [], nimcall.}
    ## Copies the components of a single row into the shape a query asked for. Returns
    ## false for rows that the query turns out not to want after all

  QuerySpan*[Comps: tuple] = object
    ## A run of consecutive rows belonging to one archetype. Queries hand these out rather
    ## than individual rows so that the walk over the rows stays in the caller, where the
    ## cursor lives in registers instead of behind a call
    archSpan: ArchRowSpan
    convert: QueryConvert[Comps]

  QueryGetSpan*[Comps: tuple] = proc(
    appStatePtr: pointer, state: var uint, span: var QuerySpan[Comps]
  ): bool {.gcsafe, raises: [], nimcall.}

  QueryGetLen = proc(appState: pointer): Natural {.gcsafe, raises: [], nimcall.}

  RawQuery*[Comps] = ref object
    ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
    ## the components to fetch in this query.
    appState: pointer
    getLen: QueryGetLen
    getSpan: QueryGetSpan[Comps]

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
    appState: pointer, getLen: QueryGetLen, getSpan: QueryGetSpan[Comps]
): RawQuery[Comps] =
  RawQuery[Comps](appState: appState, getLen: getLen, getSpan: getSpan)

proc newQuerySpan*[Comps: tuple](
    archSpan: ArchRowSpan, convert: QueryConvert[Comps]
): QuerySpan[Comps] {.inline.} =
  ## Describes a run of rows to be walked by a query
  QuerySpan[Comps](archSpan: archSpan, convert: convert)

iterator rows*[Comps: tuple](span: QuerySpan[Comps], slot: var Comps): RawArchRow =
  ## Walks the rows of a span that the query actually wants, filling `slot` with the
  ## components of each
  let convert = span.convert
  for row in span.archSpan.rows:
    if likely(convert(row.components, nil, slot)):
      yield row

iterator pairs*[Comps: tuple](query: FullQuery[Comps]): QueryItem[Comps] =
  ## Iterates through the entities in a query
  let raw = RawQuery[Comps](query)
  var state: uint
  var span: QuerySpan[Comps]
  var slot: Comps
  while raw.getSpan(raw.appState, state, span):
    for row in span.rows(slot):
      yield (row.entityId, slot)

iterator items*[Comps: tuple](query: AnyQuery[Comps]): Comps =
  ## Iterates through the entities in a query
  let raw = RawQuery[Comps](query)
  var state: uint
  var span: QuerySpan[Comps]
  var slot: Comps
  while raw.getSpan(raw.appState, state, span):
    for _ in span.rows(slot):
      yield slot

proc len*[Comps: tuple](query: AnyQuery[Comps]): Natural {.gcsafe, raises: [].} =
  ## Returns the number of entities in this query
  let rawQuery = RawQuery[Comps](query)
  return rawQuery.getLen(rawQuery.appState)

proc single*[Comps: tuple](query: AnyQuery[Comps]): Option[Comps] =
  ## Returns a single element from a query
  for comps in query:
    return some(comps)
