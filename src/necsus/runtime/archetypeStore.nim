import world, entityId, ../util/blockstore

type
    ArchRow*[Comps: tuple] = tuple[entityId: EntityId, components: Comps]
        ## A row of data stored about an entity that matches a specific archetype

    ArchetypeStore*[Archs: enum, Comps: tuple] = ref object
        ## Stores a specific archetype shape
        archetype: Archs
        initialSize: int
        compStore: BlockStore[ArchRow[Comps]]

    NewArchSlot*[Comps: tuple] = distinct Entry[ArchRow[Comps]]

    ArchetypeIter* = distinct BlockIter
        ## A manual iterator instance

proc newArchetypeStore*[Archs: enum, Comps: tuple](
    archetype: Archs,
    initialSize: SomeInteger
): ArchetypeStore[Archs, Comps] =
    ## Creates a new storage block for an archetype
    ArchetypeStore[Archs, Comps](initialSize: initialSize.int, archetype: archetype)

proc archetype*[Archs: enum, Comps: tuple](store: ArchetypeStore[Archs, Comps]): Archs {.inline.} = store.archetype
    ## Accessor for the archetype of a store

proc next*[Archs: enum, Comps: tuple](store: ArchetypeStore[Archs, Comps], iter: var ArchetypeIter): ptr ArchRow[Comps] =
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

proc len*[Archs: enum, Comps: tuple](store: ArchetypeStore[Archs, Comps]): uint {.inline.} =
    ## Accessor for the archetype of a store
    return if store.compStore == nil: 0 else: store.compStore.len

proc newSlot*[Archs: enum, Comps: tuple](
    store: var ArchetypeStore[Archs, Comps],
    entityId: EntityId
): NewArchSlot[Comps] {.inline.} =
    ## Reserves a slot for storing a new component

    if store.compStore == nil:
        store.compStore = newBlockStore[ArchRow[Comps]](store.initialSize)

    let slot = store.compStore.reserve
    slot.value.entityId = entityId
    return NewArchSlot[Comps](slot)

proc index*[Comps: tuple](entry: NewArchSlot[Comps]): uint {.inline.} = Entry[ArchRow[Comps]](entry).index

proc setComp*[Comps: tuple](slot: NewArchSlot[Comps], comps: sink Comps): EntityId {.inline.} =
    ## Stores an entity and its components into this slot
    let entry = Entry[ArchRow[Comps]](slot)
    value(entry).components = comps
    commit(entry)
    return value(entry).entityId

proc getComps*[Archs: enum, Comps: tuple](store: var ArchetypeStore[Archs, Comps], index: uint): ptr Comps =
    ## Return the components for an archetype
    unsafeAddr store.compStore[index].components

proc del*(store: var ArchetypeStore, index: uint) =
    ## Return the components for an archetype
    discard store.compStore.del(index)

proc moveEntity*[Archs: enum, FromArch: tuple, ToArch: tuple](
    world: var World[Archs],
    entityIndex: ptr EntityIndex[Archs],
    fromArch: var ArchetypeStore[Archs, FromArch],
    toArch: var ArchetypeStore[Archs, ToArch],
    convert: proc (input: sink FromArch): ToArch {.gcsafe, raises: [].}
) {.inline, gcsafe, raises: [].} =
    ## Moves the components for an entity from one archetype to another
    let deleted = fromArch.compStore.del(entityIndex.archetypeIndex)
    let existing = deleted.components
    let newSlot = newSlot[Archs, ToArch](toArch, entityIndex.entityId)
    discard setComp(newSlot, convert(existing))
    entityIndex.archetype = toArch.archetype
    entityIndex.archetypeIndex = newSlot.index
