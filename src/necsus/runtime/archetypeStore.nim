import world, entityId, ../util/blockstore

type
    ArchRow[Comps: tuple] = object
        ## A row of data stored about an entity that matches a specific archetype
        entityId: EntityId
        components: Comps

    ArchetypeStore*[Archs: enum, Comps: tuple] = ref object
        ## Stores a specific archetype shape
        archetype: Archs
        compStore: BlockStore[ArchRow[Comps]]

    ArchView*[ViewComps: tuple] = object
        ## An object able to iterate over an archetype using a specific view of the data
        buildIterator: proc(): iterator(): (EntityId, ViewComps)

    NewArchSlot*[Comps: tuple] = distinct Entry[ArchRow[Comps]]

proc newArchetypeStore*[Archs: enum, Comps: tuple](
    archetype: Archs,
    initialSize: SomeInteger
): ArchetypeStore[Archs, Comps] =
    ## Creates a new storage block for an archetype
    result.new
    result.compStore = newBlockStore[ArchRow[Comps]](initialSize)
    result.archetype = archetype

proc archetype*[Archs: enum, Comps: tuple](store: ArchetypeStore[Archs, Comps]): Archs {.inline.} = store.archetype
    ## Accessor for the archetype of a store

proc newSlot*[Archs: enum, Comps: tuple](
    store: var ArchetypeStore[Archs, Comps],
    entityId: EntityId
): NewArchSlot[Comps] {.inline.} =
    ## Reserves a slot for storing a new component
    let slot = store.compStore.reserve
    slot.value.entityId = entityId
    return NewArchSlot[Comps](slot)

proc index*[Comps: tuple](entry: NewArchSlot[Comps]): uint {.inline.} = Entry[ArchRow[Comps]](entry).index

proc set*[Comps: tuple](entry: NewArchSlot[Comps], comps: sink Comps): EntityId {.inline.} =
    ## Stores an entity and its components into this slot
    let entry = Entry[ArchRow[Comps]](entry)
    entry.value.components = comps
    entry.commit
    return entry.value.entityId

proc asView*[Archs: enum, ArchetypeComps: tuple, ViewComps: tuple](
    input: ArchetypeStore[Archs, ArchetypeComps],
    convert: proc (input: ptr ArchetypeComps): ViewComps
): ArchView[ViewComps] =
    ## Creates an iterable view into this component that uses the given converter
    result.buildIterator = proc(): auto =
        return iterator(): (EntityId, ViewComps) =
            for row in items(input.compStore):
                yield (row.entityId, convert(addr row.components))

iterator pairs*[ViewComps: tuple](view: ArchView[ViewComps]): (EntityId, ViewComps) {.inline.} =
    ## Iterates over the components in a view
    let instance = view.buildIterator()
    for row in instance():
        yield row

proc getComps*[Comps: tuple](store: var ArchetypeStore, index: uint): ptr Comps =
    ## Return the components for an archetype
    unsafeAddr store.compStore[index].components
