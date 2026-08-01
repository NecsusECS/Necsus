import entityId, archetypeStore, std/[typetraits, options, macros]

type
  Not*[Comps] = distinct int8
    ## A query flag that indicates a component should be excluded from a query. Where `Comps` is
    ## the single component that should be excluded.

  QueryItem*[Comps: tuple] = tuple[entityId: EntityId, components: Comps]
    ## An individual value yielded by a query. Where `Comps` is a tuple of the components to fetch in
    ## this query

  QueryCols*[Comps: tuple] = object
    ## The columns of one archetype that a query asked for, resolved once, alongside the
    ## entity ids sitting next to them and how many rows they hold.
    ##
    ## Working out where a column sits happens here rather than once per row, which is
    ## what the global component index buys: the same id names the same component in
    ## every archetype, so nothing about this depends on which archetype it came from
    rows*: uint32
    eids*: ptr UncheckedArray[EntityId]
    columns*: array[tupleLen(Comps), Column]

  QueryGetCols*[Comps: tuple] = proc(
    appStatePtr: pointer, state: var uint, cols: var QueryCols[Comps]
  ): bool {.gcsafe, raises: [], nimcall.}

  QueryGetLen = proc(appState: pointer): Natural {.gcsafe, raises: [], nimcall.}

  RawQuery*[Comps] = ref object
    ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
    ## the components to fetch in this query.
    appState: pointer
    getLen: QueryGetLen
    getCols: QueryGetCols[Comps]

  Query*[Comps: tuple] = distinct RawQuery[Comps]
    ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
    ## the components to fetch in this query. Does not provide access to the entity ID

  FullQuery*[Comps: tuple] = distinct RawQuery[Comps]
    ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
    ## the components to fetch in this query. Provides access to the EntityId

  AnyQuery*[Comps: tuple] = Query[Comps] | FullQuery[Comps]

proc asFullQuery*[Comps](rawQuery: RawQuery[Comps]): FullQuery[Comps] =
  FullQuery[Comps](rawQuery)

proc asQuery*[Comps](rawQuery: RawQuery[Comps]): Query[Comps] =
  Query[Comps](rawQuery)

proc newQuery*[Comps: tuple](
    appState: pointer, getLen: QueryGetLen, getCols: QueryGetCols[Comps]
): RawQuery[Comps] =
  RawQuery[Comps](appState: appState, getLen: getLen, getCols: getCols)

proc newQueryCols*[Comps: tuple](
    store: ArchetypeStore, components: openArray[ComponentId]
): QueryCols[Comps] {.inline.} =
  ## Picks out the columns a query wants from an archetype.
  ##
  ## A component the archetype does not have leaves a nil column behind, which is exactly
  ## what an excluded or absent optional argument wants -- so nothing here has to be told
  ## which arguments those are
  assert(
    components.len == result.columns.len,
    "A query needs exactly one component per argument",
  )
  result.rows = store.rows
  result.eids = store.entities
  for i in 0 ..< components.len:
    result.columns[i] = store.column(components[i])

template readCol*[T](column: Column, idx: uint32, slot: var T) =
  ## Reads one component out of a column. The slot is what says how to read it
  slot = column.read(T, idx)

template readCol*[T](column: Column, idx: uint32, slot: var ptr T) =
  ## A query that asked for a pointer gets one straight into the column, so nothing is
  ## copied and writes land back in the store
  slot = column.at(T, idx)

template readCol*[T](column: Column, idx: uint32, slot: var Not[T]) =
  ## An excluded component has no column. The archetype already established it is absent,
  ## so there is nothing to read and nothing to check
  discard

template readCol*[T](column: Column, idx: uint32, slot: var Option[T]) =
  ## An optional component is present or it is not, and an empty column is how the
  ## archetype says which
  slot =
    if column.isEmpty:
      none(T)
    else:
      some(column.read(T, idx))

macro unrollRead(arity: static int, cols, idx, slot: typed): untyped =
  ## Emits one read per column with the index spelled out as a literal.
  ##
  ## Walking the fields with a counter would leave the column index as a runtime value,
  ## which drags a bounds check and an overflow check into every read. Naming the index
  ## up front means there is nothing left to check
  result = newStmtList()
  for i in 0 ..< arity:
    result.add newCall(
      bindSym("readCol"),
      nnkBracketExpr.newTree(newDotExpr(cols, ident("columns")), newLit(i)),
      idx,
      nnkBracketExpr.newTree(slot, newLit(i)),
    )

template read*[Comps: tuple](cols: QueryCols[Comps], idx: uint32, slot: var Comps) =
  ## Fills a slot with one row. Each field becomes a plain indexed load from its column
  unrollRead(tupleLen(Comps), cols, idx, slot)

macro walkRows(arity: static int, cols, slot, body: untyped): untyped =
  ## Emits the row loop for a single archetype, with everything the loop needs lifted
  ## out of `cols` first.
  ##
  ## Reading straight out of `cols` looks equivalent, but `cols` has had its address
  ## taken -- it is filled in through a `var` parameter -- and the generated C is built
  ## with `-fno-strict-aliasing`. Between the two, a write through any column pointer is
  ## something the C compiler has to assume might have landed on `cols` itself, so it
  ## reloads every column base and the row count from the stack on every single row, and
  ## gives up on vectorizing the loop. Copies in plain locals cannot be aliased by
  ## anything, so they stay in registers and the loop is free to be widened
  let rows = genSym(nskLet, "rows")
  result = newStmtList()

  var reads = newStmtList()
  for i in 0 ..< arity:
    let col = genSym(nskLet, "col" & $i)
    result.add newLetStmt(
      col, nnkBracketExpr.newTree(newDotExpr(cols, ident("columns")), newLit(i))
    )
    reads.add newCall(
      bindSym("readCol"), col, ident("idx"), nnkBracketExpr.newTree(slot, newLit(i))
    )

  result.add newLetStmt(rows, newDotExpr(cols, ident("rows")))
  reads.add body
  result.add nnkForStmt.newTree(
    ident("idx"),
    nnkInfix.newTree(ident("..<"), newLit(0'u32), rows),
    newBlockStmt(reads),
  )
  result = newBlockStmt(result)

iterator pairs*[Comps: tuple](query: FullQuery[Comps]): QueryItem[Comps] =
  ## Iterates through the entities in a query
  let raw = RawQuery[Comps](query)
  var state: uint
  var cols: QueryCols[Comps]
  var slot: Comps
  while raw.getCols(raw.appState, state, cols):
    let eids = cols.eids
    walkRows(tupleLen(Comps), cols, slot):
      yield (eids[idx], slot)

iterator items*[Comps: tuple](query: AnyQuery[Comps]): Comps =
  ## Iterates through the entities in a query
  let raw = RawQuery[Comps](query)
  var state: uint
  var cols: QueryCols[Comps]
  var slot: Comps
  while raw.getCols(raw.appState, state, cols):
    walkRows(tupleLen(Comps), cols, slot):
      yield slot

proc len*[Comps: tuple](query: AnyQuery[Comps]): Natural {.gcsafe, raises: [].} =
  ## Returns the number of entities in this query
  let rawQuery = RawQuery[Comps](query)
  return rawQuery.getLen(rawQuery.appState)

proc single*[Comps: tuple](query: AnyQuery[Comps]): Option[Comps] =
  ## Returns a single element from a query
  for comps in query:
    return some(comps)
