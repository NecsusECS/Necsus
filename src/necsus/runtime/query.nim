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
    hasAccessories*: bool
      ## Whether any argument at all is backed by an accessory column, which is what says
      ## whether the rows have to be filtered as they are walked
    eids*: ptr UncheckedArray[EntityId]
    columns*: array[tupleLen(Comps), Column]
    accessories*: array[tupleLen(Comps), bool]
      ## Which arguments are backed by an accessory column.

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
    store: ArchetypeStore,
    components: openArray[ComponentId],
    accessories: openArray[bool],
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
    result.accessories[i] = accessories[i]
    result.hasAccessories = result.hasAccessories or accessories[i]

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

template readCol*[T](column: Column, idx: uint32, slot: var Option[ptr T]) =
  ## An optional component asked for by pointer. Without this, the option overload above
  ## matches with `T` bound to `ptr T` and reads the component itself as a pointer
  slot =
    if column.isEmpty:
      none(ptr T)
    else:
      some(column.at(T, idx))

template readAccCol*[T](column: Column, isAcc: bool, idx: uint32, slot: var T): bool =
  ## Reads a required component that may be held as an accessory, and says whether the
  ## row turned out to have it.
  if isAcc:
    let opt = column.at(Option[T], idx)
    if opt[].isSome:
      slot = opt[].unsafeGet
      true
    else:
      false
  else:
    slot = column.read(T, idx)
    true

template readAccCol*[T](
    column: Column, isAcc: bool, idx: uint32, slot: var ptr T
): bool =
  ## A required component asked for by pointer. An accessory hands back a pointer to the
  ## value inside the option rather than to the option itself
  if isAcc:
    let opt = column.at(Option[T], idx)
    if opt[].isSome:
      slot = unsafeAddr opt[].unsafeGet
      true
    else:
      false
  else:
    slot = column.at(T, idx)
    true

template readAccCol*[T](
    column: Column, isAcc: bool, idx: uint32, slot: var Not[T]
): bool =
  ## An excluded component usually has no column at all, which the archetype settled once
  ## and for all. An excluded accessory does have one. The archetype holds entities both
  ## with and without it, so it is the row that has to be checked
  (not isAcc) or column.isEmpty or column.at(Option[T], idx)[].isNone

template readAccCol*[T](
    column: Column, isAcc: bool, idx: uint32, slot: var Option[T]
): bool =
  ## An optional component. An accessory column is already holding exactly the option
  ## being asked for, so it comes straight back out
  slot =
    if column.isEmpty:
      none(T)
    elif isAcc:
      column.read(Option[T], idx)
    else:
      some(column.read(T, idx))
  true

template readAccCol*[T](
    column: Column, isAcc: bool, idx: uint32, slot: var Option[ptr T]
): bool =
  ## An optional component asked for by pointer. Without this, the option overload above
  ## matches with `T` bound to `ptr T` and reads the component itself as a pointer
  slot =
    if column.isEmpty:
      none(ptr T)
    elif isAcc:
      let opt = column.at(Option[T], idx)
      if opt[].isSome:
        some(unsafeAddr opt[].unsafeGet)
      else:
        none(ptr T)
    else:
      some(column.at(T, idx))
  true

proc isAccArg(cols: NimNode, i: int): NimNode =
  ## Whether one argument of a query is backed by an accessory column
  nnkBracketExpr.newTree(newDotExpr(cols, ident("accessories")), newLit(i))

proc accReads(cols: NimNode, columns: seq[NimNode], idx, slot: NimNode): NimNode =
  ## Chains the read of every column into the one condition of whether the row is a match.
  result = newLit(true)
  for i, column in columns:
    let read = newCall(
      bindSym("readAccCol"),
      column,
      cols.isAccArg(i),
      idx,
      nnkBracketExpr.newTree(copyNimTree(slot), newLit(i)),
    )
    result =
      if i == 0:
        read
      else:
        nnkInfix.newTree(ident("and"), result, read)

macro unrollRead(arity: static int, cols, idx, slot: typed): untyped =
  ## Emits one read per column with the index spelled out as a literal.
  ##
  ## Walking the fields with a counter would leave the column index as a runtime value,
  ## which drags a bounds check and an overflow check into every read. Naming the index
  ## up front means there is nothing left to check
  var columns: seq[NimNode]
  for i in 0 ..< arity:
    columns.add nnkBracketExpr.newTree(newDotExpr(cols, ident("columns")), newLit(i))
  accReads(cols, columns, idx, slot)

template read*[Comps: tuple](
    cols: QueryCols[Comps], idx: uint32, slot: var Comps
): bool =
  ## Fills a slot with one row, and says whether the row was a match at all -- which it
  ## may not be, when the row is missing an accessory that was asked for
  unrollRead(tupleLen(Comps), cols, idx, slot)

proc rowLoop(rows, idx, reads: NimNode): NimNode =
  ## Walks every row of an archetype, running `reads` against each.
  let cursor = genSym(nskVar, "cursor")
  newStmtList(
    newVarStmt(cursor, rows),
    nnkWhileStmt.newTree(
      nnkInfix.newTree(ident(">"), cursor, newLit(0'u32)),
      newStmtList(
        newAssignment(cursor, nnkInfix.newTree(ident("-"), cursor, newLit(1'u32))),
        newLetStmt(idx, cursor),
        newBlockStmt(reads),
      ),
    ),
  )

macro walkRows(arity: static int, cols, slot, body: untyped): untyped =
  ## Emits the row loop for a single archetype, with everything the loop needs lifted
  ## out of `cols` first.

  # Reading straight out of `cols` looks equivalent, but `cols` has had its address
  # taken -- it is filled in through a `var` parameter -- and the generated C is built
  # with `-fno-strict-aliasing`. Between the two, a write through any column pointer is
  # something the C compiler has to assume might have landed on `cols` itself, so it
  # reloads every column base and the row count from the stack on every single row, and
  # gives up on vectorizing the loop. Copies in plain locals cannot be aliased by
  # anything, so they stay in registers and the loop is free to be widened
  #
  # Rows are walked back to front, which is what makes it safe for the body to delete the
  # entity it is looking at. Deleting a row fills the hole with the last one, so walking
  # forwards would move a row that has not been reached yet down to a position already
  # passed -- skipping it -- and would keep running past a row count that has since
  # shrunk. Going backwards, the row that moves always comes from at or above the cursor,
  # which has already been visited, and the cursor can never outrun the live row count
  let rows = genSym(nskLet, "rows")
  result = newStmtList()

  var columns: seq[NimNode]
  for i in 0 ..< arity:
    let col = genSym(nskLet, "col" & $i)
    result.add newLetStmt(
      col, nnkBracketExpr.newTree(newDotExpr(cols, ident("columns")), newLit(i))
    )
    columns.add(col)

  result.add newLetStmt(rows, newDotExpr(cols, ident("rows")))

  let plainIdx = ident("idx")
  var plain = newStmtList()
  for i, column in columns:
    plain.add newCall(
      bindSym("readCol"),
      column,
      plainIdx,
      nnkBracketExpr.newTree(copyNimTree(slot), newLit(i)),
    )
  plain.add copyNimTree(body)

  let checkedIdx = ident("idx")
  let checked = newIfStmt(
    (accReads(cols, columns, checkedIdx, slot), newStmtList(copyNimTree(body)))
  )

  # Rows holding an accessory have to be filtered as they are walked, and the columns
  # holding one are read as options rather than as the component itself. Which archetypes
  # those are is not known until runtime, but it is settled for a whole archetype at a
  # time. So the test goes outside the loop and there are two loops rather than a branch
  # on every row. A query with no accessory in sight is then exactly the loop it always
  # was, with nothing in the body to stop it being vectorized
  result.add nnkIfStmt.newTree(
    nnkElifBranch.newTree(
      nnkPrefix.newTree(ident("not"), newDotExpr(cols, ident("hasAccessories"))),
      rowLoop(rows, plainIdx, plain),
    ),
    nnkElse.newTree(rowLoop(rows, checkedIdx, checked)),
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
