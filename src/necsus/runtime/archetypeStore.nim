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
        buildIterator: proc(): iterator(slot: var ViewComps): EntityId
        length: proc(): uint

    NewArchSlot*[Comps: tuple] = distinct Entry[ArchRow[Comps]]

proc newArchetypeStore*[Archs: enum, Comps: tuple](
    archetype: Archs,
    initialSize: SomeInteger
): ArchetypeStore[Archs, Comps] =
    ## Creates a new storage block for an archetype
    let inst = new(ArchetypeStore[Archs, Comps])
    inst.compStore = newBlockStore[ArchRow[Comps]](initialSize)
    inst.archetype = archetype
    return inst

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

proc setComp*[Comps: tuple](slot: NewArchSlot[Comps], comps: Comps): EntityId {.inline.} =
    ## Stores an entity and its components into this slot
    let entry = Entry[ArchRow[Comps]](slot)
    value(entry).components = comps
    commit(entry)
    return value(entry).entityId

proc asView*[Archs: enum, ArchetypeComps: tuple, ViewComps: tuple](
    input: ArchetypeStore[Archs, ArchetypeComps],
    convert: proc (input: ptr ArchetypeComps): ViewComps
): ArchView[ViewComps] =
    ## Creates an iterable view into this component that uses the given converter
    result.buildIterator = proc(): auto =
        return iterator(comps: var ViewComps): EntityId =
            for row in items(input.compStore):
                comps = convert(addr row.components)
                yield row.entityId
    result.length = proc(): auto = input.compStore.len

iterator items*[ViewComps: tuple](view: ArchView[ViewComps], comps: var ViewComps): EntityId {.inline.} =
    ## Iterates over the components in a view
    let instance = view.buildIterator()
    for entityId in instance(comps):
        yield entityId

proc len*[ViewComps: tuple](view: ArchView[ViewComps]): uint {.inline.} =
    ## Iterates over the components in a view
    view.length()

proc getComps*[Archs: enum, Comps: tuple](store: var ArchetypeStore[Archs, Comps], index: uint): ptr Comps =
    ## Return the components for an archetype
    unsafeAddr store.compStore[index].components

proc del*(store: var ArchetypeStore, index: uint) =
    ## Return the components for an archetype
    store.compStore.del(index)

proc moveEntity*[Archs: enum, FromArch: tuple, ToArch: tuple](
    world: var World[Archs],
    entityIndex: ptr EntityIndex[Archs],
    fromArch: var ArchetypeStore[Archs, FromArch],
    toArch: var ArchetypeStore[Archs, ToArch],
    convert: proc (input: ptr FromArch): ToArch
) {.inline.} =
    ## Moves the components for an entity from one archetype to another
    let existing = getComps[Archs, FromArch](fromArch, entityIndex.archetypeIndex)
    let newSlot = newSlot[Archs, ToArch](toArch, entityIndex.entityId)
    discard setComp(newSlot, convert(existing))
    fromArch.del(entityIndex.archetypeIndex)
    entityIndex.archetype = toArch.archetype
    entityIndex.archetypeIndex = newSlot.index
