import world, entityId

type
  ComponentId* = uint16
    ## The global index of a component. Every archetype indexes its columns by the same
    ## ids, which is what lets a query resolve a column without knowing which archetype
    ## it came from

  Column* = distinct pointer
    ## A column of some component. Nothing here knows which -- only the site that
    ## resolved the column does, and it reads the column as the type it knows about

  AccessoryFlag* = bool
    ## What the presence column of an accessory holds, one per row.
    ##
    ## An accessory belongs to an entity rather than to an archetype, so an archetype that
    ## has one holds rows both with and without it. The value lives in an ordinary column
    ## and whether the row has it at all lives in a column of its own, which means a walk
    ## that only cares about presence never has to touch the values

  ColumnDef* = object
    ## Describes one column an archetype needs room for. The sizes come from `sizeof` and
    ## `alignof` at the site that knows the component type, so nothing has to be carried
    ## around to describe a component at runtime
    id: ComponentId
    size, align: uint32

  ArchetypeStore*[N: static int] = object
    ## Stores the entities of one archetype, a column per component.
    ##
    ## `N` is the number of components in the whole app, so there is one instantiation of
    ## this per app rather than one per archetype shape. Holding the column table inline
    ## keeps reaching a column down to a single load at a constant offset, and everything
    ## claiming a row needs sits ahead of that table, so a spawn touches one cache line
    ## however many components the app has
    archetype: ArchetypeId
    used: uint32
    capacity: uint32
      ## How many rows there is room for right now, which is none until the memory to hold
      ## them has been claimed. Reserving a row already has to check this, so leaving it at
      ## zero is what lets an archetype notice its first entity without the hot path
      ## growing a second test
    rowLimit: uint32 ## How many rows there will be room for once the memory arrives
    eids: ptr UncheckedArray[EntityId]
    blk: pointer
    blockSize: uint
    columns: array[N, Column]

const NO_COLUMN* = Column(nil)
  ## What an archetype holds for a component it does not have

proc isEmpty*(column: Column): bool {.inline, raises: [].} =
  ## Whether an archetype had this column at all. An archetype without a component leaves
  ## nothing behind for it, which is how an absent component is told apart from a present one
  pointer(column) == nil

template at*(column: Column, T: typedesc, index: uint32): untyped =
  ## Points at one value in a column. A column does not know what it holds, so the caller
  ## is the one that names the type.
  ##
  ## Handing back a pointer rather than a value is what keeps the caller in charge of
  ## whether anything gets copied. This is a template so that reading a column stays a
  ## plain indexed load at the site that asked for it, with no call to be seen through
  addr cast[ptr UncheckedArray[T]](column)[index]

template read*(column: Column, T: typedesc, index: uint32): untyped =
  ## Reads one value out of a column
  column.at(T, index)[]

func columnDef*[T](id: ComponentId): ColumnDef =
  ## Describes the column a component needs. How much room a component takes is a property
  ## of the component rather than of any archetype, so this is meant to be worked out once
  ## and shared by every archetype that has that component
  ColumnDef(id: id, size: uint32(sizeof(T)), align: uint32(alignof(T)))

proc `=copy`*[N: static int](
  target: var ArchetypeStore[N], source: ArchetypeStore[N]
) {.error.}

proc roundUp(offset, align: uint): uint {.inline.} =
  ## The next offset at or after `offset` that satisfies an alignment
  let mask = align - 1
  (offset + mask) and not mask

proc newArchetypeStore*[N: static int](
    archetype: ArchetypeId, capacity: Natural, columns: openArray[ColumnDef]
): ArchetypeStore[N] =
  ## Lays out the storage for a single archetype, without claiming any memory for it yet.
  ##
  ## Everything lands in one allocation, arranged as the entity ids followed by each column
  ## in turn, with each column started at an offset its component is happy to be aligned
  ## to. Working the layout out up front means the column table can hold the offset each
  ## column will sit at, so nothing has to remember what the columns were to be able to
  ## allocate later
  result.archetype = archetype
  result.rowLimit = uint32(capacity)

  if capacity == 0:
    return

  var offset = uint(sizeof(EntityId)) * uint(capacity)
  for column in columns:
    offset = roundUp(offset, uint(column.align))
    result.columns[column.id] = Column(cast[pointer](offset))
    offset += uint(column.size) * uint(capacity)

  result.blockSize = offset

proc ensureAlloced*[N: static int](store: var ArchetypeStore[N]) {.noinline.} =
  ## Claims the memory backing an archetype, if it doesn't have any yet.
  ##
  ## An app describes more archetypes than it tends to fill, and each one is sized for the
  ## whole app, so waiting until an entity actually arrives keeps the archetypes that never
  ## see one down to nothing at all. The column table holds offsets until this runs, which
  ## is what turns them into the pointers everything else reads
  if store.blk != nil or store.blockSize == 0:
    return

  store.blk = alloc0(store.blockSize)
  store.eids = cast[ptr UncheckedArray[EntityId]](store.blk)

  for column in store.columns.mitems:
    if not column.isEmpty:
      column = Column(cast[pointer](cast[uint](store.blk) + cast[uint](column)))

  store.capacity = store.rowLimit

proc len*(store: ArchetypeStore): Natural {.inline.} =
  ## The number of entities currently stored
  Natural(store.used)

proc addLen*(store: ArchetypeStore, len: var Natural) {.inline.} =
  ## Adds the number of entities in this archetype onto a running total
  len += Natural(store.used)

proc rows*(store: ArchetypeStore): uint32 {.inline, raises: [].} =
  ## The number of rows every column in this archetype currently holds
  store.used

proc entities*(
    store: ArchetypeStore
): ptr UncheckedArray[EntityId] {.inline, raises: [].} =
  ## The entity ids sitting alongside the columns, one per row and in the same order
  store.eids

proc column*(
    store: ArchetypeStore, component: ComponentId
): Column {.inline, raises: [].} =
  ## The column holding a component, or `NO_COLUMN` when this archetype does not have it.
  ##
  ## Component ids are global, so this is the same lookup in every archetype -- which is
  ## what lets a caller resolve a column without knowing which archetype it came from.
  ##
  ## Only worth reading once the archetype has rows in it: an archetype yet to be allocated
  ## is still carrying the offset each column is going to sit at rather than a pointer to
  ## it. Every caller already asks about rows first, because a column of an empty archetype
  ## has nothing in it to read
  store.columns[component]

proc getColumn*[T](
    store: ArchetypeStore, component: ComponentId
): ptr UncheckedArray[T] {.inline.} =
  ## Reads a column as the component it holds. The caller is the one that knows which
  ## component sits at an id, so it is the caller that names the type
  cast[ptr UncheckedArray[T]](store.column(component))

proc reserve*(store: var ArchetypeStore, entityId: EntityId): uint32 =
  ## Claims the next row for an entity and returns its index.
  if unlikely(store.used >= store.capacity):
    # An archetype with no memory behind it has room for nothing, so running out of room is
    # also how it finds out it is being filled for the first time
    store.ensureAlloced()
    if unlikely(store.used >= store.capacity):
      raise newException(IndexDefect, "Archetype capacity exceeded: " & $store.rowLimit)
  result = store.used
  store.used += 1
  store.eids[result] = entityId

proc setComponent*[T](
    store: var ArchetypeStore, component: ComponentId, index: uint32, value: sink T
) {.inline.} =
  ## Stores a single component in a row. The row was zeroed when it was reserved, so the
  ## assignment has a valid value to sink over
  getColumn[T](store, component)[index] = value

proc entityId*(store: ArchetypeStore, index: uint32): EntityId {.inline.} =
  store.eids[index]

iterator entityIds*(store: ArchetypeStore): EntityId =
  ## Walks every entity in this archetype
  for i in 0'u32 ..< store.used:
    yield store.eids[i]

proc destroyColumn*[T](store: var ArchetypeStore, component: ComponentId) =
  ## Destroys the live values in a single column. Columns hold raw memory, so nothing
  ## else is going to run a destructor over them
  let column = getColumn[T](store, component)
  for i in 0'u32 ..< store.used:
    `=destroy`(column[i])

proc relocateLast[T](column: ptr UncheckedArray[T], index, last: uint32) {.inline.} =
  ## Fills a vacated row with the last one, and leaves the row the last one came from
  ## reading as zero.
  if index != last:
    copyMem(addr column[index], addr column[last], sizeof(T))
  wasMoved(column[last])

proc dropColumn*[T](store: var ArchetypeStore, component: ComponentId, index: uint32) =
  ## Destroys one value in a column and relocates the last row into the hole it leaves
  let column = getColumn[T](store, component)
  `=destroy`(column[index])
  relocateLast(column, index, store.used - 1)

proc clearColumn*[T](store: var ArchetypeStore, component: ComponentId, index: uint32) =
  ## Destroys one value in a column without disturbing any other row, leaving the slot
  ## reading as zero. This is how an accessory is taken off an entity that stays where it
  ## is: the row is still live, so nothing gets relocated into it
  let column = getColumn[T](store, component)
  `=destroy`(column[index])
  wasMoved(column[index])

proc takeColumn*[T](
    store: var ArchetypeStore, component: ComponentId, index: uint32
): T =
  ## Moves one value out of a column and relocates the last row into the hole it leaves.
  let column = getColumn[T](store, component)
  result = move(column[index])
  relocateLast(column, index, store.used - 1)

proc dropRow*(store: var ArchetypeStore, index: uint32): EntityId {.discardable.} =
  ## Finishes a delete once every column has been dropped, moving the last entity id down
  ## to fill the hole.
  ##
  ## Returns the entity that moved, so the caller can correct the archetype index it has
  ## recorded for it. Returns the deleted entity when nothing had to move
  store.used -= 1
  result = store.eids[index]
  if index != store.used:
    result = store.eids[store.used]
    store.eids[index] = result

proc `=destroy`*[N: static int](store: var ArchetypeStore[N]) =
  ## Releases the memory backing an archetype. Every column has to have been destroyed
  ## before this runs, because afterwards there is nothing left to say what was in them
  if store.blk != nil:
    dealloc(store.blk)
    store.blk = nil
    store.eids = nil
  for i in 0 ..< store.columns.len:
    store.columns[i] = NO_COLUMN
  store.used = 0
  store.capacity = 0
  store.rowLimit = 0
  store.blockSize = 0
