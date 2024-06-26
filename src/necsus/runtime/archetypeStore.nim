import world, entityId, ../util/blockstore

type
    ArchRow*[Comps: tuple] = object
        ## A row of data stored about an entity that matches a specific archetype
        entityId*: EntityId
        components*: Comps

    ArchetypeStore*[Archs: enum, Comps: tuple] = ref object
        ## Stores a specific archetype shape
        archetype: Archs
        initialSize: int
        compStore: BlockStore[ArchRow[Comps]]

    NewArchSlot*[Comps: tuple] = distinct Entry[ArchRow[Comps]]

    ArchetypeIter* = distinct BlockIter
        ## A manual iterator instance

proc `=copy`*[Comps: tuple](target: var ArchRow[Comps], source: ArchRow[Comps]) {.error.}

proc newArchetypeStore*[Archs: enum, Comps: tuple](
    archetype: Archs,
    initialSize: SomeInteger
): ArchetypeStore[Archs, Comps] =
    ## Creates a new storage block for an archetype
    ArchetypeStore[Archs, Comps](initialSize: initialSize.int, archetype: archetype)

proc isFirst*(iter: ArchetypeIter): bool = BlockIter(iter).isFirst

proc archetype*[Archs: enum, Comps: tuple](store: ArchetypeStore[Archs, Comps]): Archs = store.archetype
    ## Accessor for the archetype of a store

proc next*[Archs: enum, Comps: tuple](
    store: ArchetypeStore[Archs, Comps],
    iter: var ArchetypeIter
): ptr ArchRow[Comps] =
    ## Returns the next value for an interator
    return if store.compStore == nil: nil else: store.compStore.next(BlockIter(iter))

iterator items*[Archs: enum, Comps: tuple](store: ArchetypeStore[Archs, Comps]): ptr ArchRow[Comps] =
    ## Iterates over the components in a view
    var iter: ArchetypeIter
    var value: ptr ArchRow[Comps]
    while true:
        value = store.next(iter)
        if value == nil:
            break
        yield value[]

func addLen*[Archs: enum, Comps: tuple](store: ArchetypeStore[Archs, Comps], len: var uint) =
    ## Accessor for the archetype of a store
    if store.compStore != nil:
        len += store.compStore.len

proc newSlot*[Archs: enum, Comps: tuple](
    store: var ArchetypeStore[Archs, Comps],
    entityId: EntityId
): NewArchSlot[Comps] =
    ## Reserves a slot for storing a new component

    if store.compStore == nil:
        store.compStore = newBlockStore[ArchRow[Comps]](store.initialSize)

    let slot = store.compStore.reserve
    slot.value.entityId = entityId
    return NewArchSlot[Comps](slot)

proc entityId*[Comps: tuple](entry: NewArchSlot[Comps]): EntityId =
    Entry[ArchRow[Comps]](entry).value.entityId

proc index*[Comps: tuple](entry: NewArchSlot[Comps]): uint = Entry[ArchRow[Comps]](entry).index

proc setComp*[Comps: tuple](slot: NewArchSlot[Comps], comps: sink Comps): EntityId =
    ## Stores an entity and its components into this slot
    let entry = Entry[ArchRow[Comps]](slot)
    value(entry).components = comps
    commit(entry)
    return value(entry).entityId

proc getComps*[Archs: enum, Comps: tuple](store: var ArchetypeStore[Archs, Comps], index: uint): ptr Comps =
    ## Return the components for an archetype
    addr store.compStore[index].components

proc del*(store: var ArchetypeStore, index: uint) =
    ## Return the components for an archetype
    discard store.compStore.del(index)

proc moveEntity*[Archs: enum, FromArch: tuple, NewComps : tuple, ToArch: tuple](
    world: var World[Archs],
    entityIndex: ptr EntityIndex[Archs],
    fromArch: var ArchetypeStore[Archs, FromArch],
    toArch: var ArchetypeStore[Archs, ToArch],
    newValues: sink NewComps,
    combine: proc (existing: sink FromArch, newValues: sink NewComps, output: var ToArch) {.gcsafe, raises: [], fastcall.}
) {.gcsafe, raises: [].} =
    ## Moves the components for an entity from one archetype to another
    let deleted = fromArch.compStore.del(entityIndex.archetypeIndex)
    let existing = deleted.components
    let newSlot = newSlot[Archs, ToArch](toArch, entityIndex.entityId)
    var output: ToArch
    combine(existing, newValues, output)
    discard setComp(newSlot, output)
    entityIndex.archetype = toArch.archetype
    entityIndex.archetypeIndex = newSlot.index
