import world, entityId

type
  ComponentId* = uint16
    ## The global index of a component. Every archetype indexes its columns by the same
    ## ids, which is what lets a query resolve a column without knowing which archetype
    ## it came from

  Column* = distinct pointer
    ## A column of some component. Nothing here knows which -- only the site that
    ## resolved the column does, and it reads the column as the type it knows about

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
    ## keeps reaching a column down to a single load at a constant offset
    archetype: ArchetypeId
    used, capacity: uint32
    eids: ptr UncheckedArray[EntityId]
    columns: array[N, Column]
    blk: pointer

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
  ## Creates the storage for a single archetype.
  ##
  ## Everything lands in one allocation, laid out as the entity ids followed by each
  ## column in turn, with each column started at an offset its component is happy to be
  ## aligned to
  result.archetype = archetype
  result.capacity = uint32(capacity)

  if capacity == 0:
    return

  # A first pass works out how much room the whole thing needs, so the columns can be
  # handed out of a single block rather than allocated one by one
  var size = uint(sizeof(EntityId)) * uint(capacity)
  for column in columns:
    size = roundUp(size, uint(column.align)) + (uint(column.size) * uint(capacity))

  result.blk = alloc0(size)

  result.eids = cast[ptr UncheckedArray[EntityId]](result.blk)

  var offset = uint(sizeof(EntityId)) * uint(capacity)
  for column in columns:
    offset = roundUp(offset, uint(column.align))
    result.columns[column.id] = Column(cast[pointer](cast[uint](result.blk) + offset))
    offset += uint(column.size) * uint(capacity)

proc len*(store: ArchetypeStore): Natural {.inline.} =
  ## The number of entities currently stored
  Natural(store.used)

proc addLen*(store: ArchetypeStore, len: var Natural) {.inline.} =
  ## Adds the number of entities in this archetype onto a running total
  len += Natural(store.used)

proc rows*(store: ArchetypeStore): uint32 {.inline, raises: [].} =
  ## The number of rows every column in this archetype currently holds
  store.used

proc entities*(store: ArchetypeStore): ptr UncheckedArray[EntityId] {.inline, raises: [].} =
  ## The entity ids sitting alongside the columns, one per row and in the same order
  store.eids

proc column*(store: ArchetypeStore, component: ComponentId): Column {.inline, raises: [].} =
  ## The column holding a component, or `NO_COLUMN` when this archetype does not have it.
  ##
  ## Component ids are global, so this is the same lookup in every archetype -- which is
  ## what lets a caller resolve a column without knowing which archetype it came from
  store.columns[component]

proc getColumn*[T](
    store: ArchetypeStore, component: ComponentId
): ptr UncheckedArray[T] {.inline.} =
  ## Reads a column as the component it holds. The caller is the one that knows which
  ## component sits at an id, so it is the caller that names the type
  cast[ptr UncheckedArray[T]](store.column(component))

proc reserve*(store: var ArchetypeStore, entityId: EntityId): uint32 =
  ## Claims the next row for an entity and returns its index.
  ##
  ## The row is left zeroed, which makes it a valid destination to assign a component
  ## over the top of, and leaves any accessory column reading as `none`
  if unlikely(store.used >= store.capacity):
    raise newException(IndexDefect, "Archetype capacity exceeded: " & $store.capacity)
  result = store.used
  store.used += 1
  store.eids[result] = entityId

proc setComponent*[T](
    store: var ArchetypeStore, component: ComponentId, index: uint32, value: sink T
) {.inline.} =
  ## Stores a single component in a row. The row was zeroed when it was reserved, so the
  ## assignment has a valid value to sink over
  store.getColumn[:T](component)[index] = value

proc entityId*(store: ArchetypeStore, index: uint32): EntityId {.inline.} =
  store.eids[index]

iterator entityIds*(store: ArchetypeStore): EntityId =
  ## Walks every entity in this archetype
  for i in 0'u32 ..< store.used:
    yield store.eids[i]

proc destroyColumn*[T](store: var ArchetypeStore, component: ComponentId) =
  ## Destroys the live values in a single column. Columns hold raw memory, so nothing
  ## else is going to run a destructor over them
  let column = store.getColumn[:T](component)
  for i in 0'u32 ..< store.used:
    `=destroy`(column[i])

proc dropColumn*[T](
    store: var ArchetypeStore, component: ComponentId, index: uint32
) =
  ## Destroys one value in a column and relocates the last row into the hole it leaves.
  ##
  ## Relocation is a bitwise move: the bytes are copied and the source is marked as moved
  ## from, so no destructor runs against either end of it. That holds for any type that
  ## does not point back into itself, which covers everything in the standard library
  let column = store.getColumn[:T](component)
  let last = store.used - 1
  `=destroy`(column[index])
  if index != last:
    copyMem(addr column[index], addr column[last], sizeof(T))
    wasMoved(column[last])

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
