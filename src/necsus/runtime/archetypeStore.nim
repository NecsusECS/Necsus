import world, entityId, ../util/blockstore, std/[strformat]

type
  ArchRow*[Comps: tuple] = object
    ## A row of data stored about an entity that matches a specific archetype
    entityId*: EntityId
    components*: Comps

  ArchetypeStore*[Comps: tuple] = object ## Stores a specific archetype shape
    archetype: ArchetypeId
    initialSize: Natural
    compStore: BlockStore[ArchRow[Comps]]

  NewArchSlot*[Comps: tuple] = distinct Entry[ArchRow[Comps]]

  ArchRowSpan* = object
    ## Every row an archetype had at the moment the span was taken, described without the
    ## shape of the components in it. That is what lets a single walk cover archetypes that
    ## do not share a shape
    blockSpan: BlockSpan
    compsOffset: uint

  RawArchRow* = object
    ## A single row, reached without knowing the shape of the components in it. Where each
    ## half of the row sits is worked out here, so a caller never has to know how a row is
    ## laid out
    eid: ptr EntityId
    comps: pointer

static:
  # Rows are walked from their front, so nothing may sit ahead of the entity id. The field
  # order is the same for every instantiation, so a single shape is enough to check it
  doAssert(offsetOf(ArchRow[tuple[dummy: int]], entityId) == 0)

proc `=copy`*[Comps: tuple](
  target: var ArchRow[Comps], source: ArchRow[Comps]
) {.error.}

proc `=copy`*[Comps: tuple](
  target: var ArchetypeStore[Comps], source: ArchetypeStore[Comps]
) {.error.}

proc newArchetypeStore*[Comps: tuple](
    archetype: ArchetypeId, initialSize: Natural
): ArchetypeStore[Comps] =
  ## Creates a new storage block for an archetype
  ArchetypeStore[Comps](initialSize: initialSize, archetype: archetype)

proc readArchetype*(store: ArchetypeStore): ArchetypeId {.inline.} =
  ## Accessor for the archetype of a store
  store.archetype

proc next*[Comps: tuple](
    store: var ArchetypeStore[Comps], iter: var BlockIter, eid: var EntityId
): ptr Comps {.inline.} =
  ## Returns the next row of components in this archetype store
  let row = store.compStore.next(BlockIter(iter))
  if unlikely(row == nil):
    return nil
  eid = row.entityId
  return addr row.components

proc wholeSpan*[Comps: tuple](
    store: var ArchetypeStore[Comps]
): ArchRowSpan {.inline.} =
  ## Returns every row in this archetype. Callers walk the rows themselves, which keeps the
  ## archetype out of the per row path entirely
  ArchRowSpan(
    blockSpan: store.compStore.wholeSpan(),
    compsOffset: uint(offsetOf(ArchRow[Comps], components)),
  )

proc isEmpty*(span: ArchRowSpan): bool {.inline.} =
  ## Whether this span covers any rows at all
  span.blockSpan.isEmpty

iterator rows*(span: ArchRowSpan): RawArchRow =
  ## Walks the rows in a span, resolving where each half of a row sits as it goes
  let compsOffset = span.compsOffset
  # A row starts with its entity id, so that is what it gets walked as. The components sit
  # further along, at an offset fixed by the shape of the row
  for row in span.blockSpan.addresses(EntityId):
    yield RawArchRow(eid: row, comps: cast[pointer](cast[uint](row) + compsOffset))

proc entityId*(row: RawArchRow): EntityId {.inline.} =
  ## The entity a row belongs to. Only read if a caller actually asks for it
  row.eid[]

proc components*(row: RawArchRow): pointer {.inline.} =
  ## The components in a row, untyped. Only code generated against this archetype knows the
  ## shape well enough to read them
  row.comps

iterator entityIds*[Comps](store: var ArchetypeStore[Comps]): EntityId =
  var iter: BlockIter
  var eid: EntityId
  while store.next(iter, eid) != nil:
    yield eid

func addLen*[Comps: tuple](store: var ArchetypeStore[Comps], len: var Natural) =
  ## Accessor for the archetype of a store
  if likely(store.compStore != nil):
    len += store.compStore.len

proc addLen*[Comps: tuple](
    store: var ArchetypeStore[Comps],
    len: var Natural,
    predicate: proc(row: var Comps): bool {.nimcall, gcsafe, raises: [].},
) =
  ## Reads the length of an archetype store, using a predicate to determine whether to count a row
  if likely(store.compStore != nil):
    for row in store.compStore.items:
      if predicate(row.components):
        len += 1

proc ensureAlloced*[Comps: tuple](store: var ArchetypeStore[Comps]) =
  ## Allocs the memory for this archetype if it hasn't been alloced already
  if unlikely(store.compStore == nil):
    store.compStore = newBlockStore[ArchRow[Comps]](store.initialSize)

proc newSlot*[Comps: tuple](
    store: var ArchetypeStore[Comps], entityId: EntityId
): NewArchSlot[Comps] =
  ## Reserves a slot for storing a new component
  store.ensureAlloced()
  let slot = store.compStore.reserve
  slot.value.entityId = entityId
  return NewArchSlot[Comps](slot)

proc entityId*[Comps: tuple](entry: NewArchSlot[Comps]): EntityId =
  Entry[ArchRow[Comps]](entry).value.entityId

proc index*[Comps: tuple](entry: NewArchSlot[Comps]): uint =
  Entry[ArchRow[Comps]](entry).index

proc setComp*[Comps: tuple](slot: NewArchSlot[Comps], comps: sink Comps): EntityId =
  ## Stores an entity and its components into this slot
  let entry = Entry[ArchRow[Comps]](slot)
  value(entry).components = comps
  commit(entry)
  return value(entry).entityId

proc getComps*[Comps: tuple](store: var ArchetypeStore[Comps], index: uint): ptr Comps =
  ## Return the components for an archetype
  assert(unlikely(store.compStore != nil))
  addr store.compStore[index].components

proc del*(store: var ArchetypeStore, index: uint) =
  ## Return the components for an archetype
  assert(unlikely(store.compStore != nil))
  discard store.compStore.del(index)

proc moveEntity*[FromArch: tuple, NewComps: tuple, ToArch: tuple](
    world: var World,
    entityIndex: ptr EntityIndex,
    fromArch: var ArchetypeStore[FromArch],
    toArch: var ArchetypeStore[ToArch],
    newValues: sink NewComps,
    combine: proc(
      existing: sink FromArch, newValues: sink NewComps, output: var ToArch
    ): bool {.gcsafe, raises: [], nimcall.},
) {.gcsafe, raises: [ValueError].} =
  ## Moves the components for an entity from one archetype to another
  assert(unlikely(fromArch.compStore != nil))
  let deleted = fromArch.compStore.del(entityIndex.archetypeIndex)
  let existing = deleted.components
  let newSlot = newSlot[ToArch](toArch, entityIndex.entityId)
  var output: ToArch
  let success = combine(existing, newValues, output)
  assert(
    success, fmt"Unable to convert tuple from {$FromArch} with {$NewComps} to {$ToArch}"
  )
  discard setComp(newSlot, output)
  entityIndex.archetype = toArch.archetype
  entityIndex.archetypeIndex = newSlot.index
