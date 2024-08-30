import world, entityId, ../util/blockstore, std/[strformat]

type
    ArchRow*[Comps: tuple] = object
        ## A row of data stored about an entity that matches a specific archetype
        entityId*: EntityId
        components*: Comps

    ArchetypeStore*[Comps: tuple] = object
        ## Stores a specific archetype shape
        archetype: ArchetypeId
        initialSize: int
        compStore: BlockStore[ArchRow[Comps]]

    NewArchSlot*[Comps: tuple] = distinct Entry[ArchRow[Comps]]

proc `=copy`*[Comps: tuple](target: var ArchRow[Comps], source: ArchRow[Comps]) {.error.}

proc `=copy`*[Comps: tuple](target: var ArchetypeStore[Comps], source: ArchetypeStore[Comps]) {.error.}

proc newArchetypeStore*[Comps: tuple](
    archetype: ArchetypeId,
    initialSize: SomeInteger
): ArchetypeStore[Comps] =
    ## Creates a new storage block for an archetype
    ArchetypeStore[Comps](
        initialSize: initialSize.int,
        archetype: archetype,
        compStore: newBlockStore[ArchRow[Comps]](initialSize)
    )

proc readArchetype*(store: ArchetypeStore): ArchetypeId {.inline.} = store.archetype
    ## Accessor for the archetype of a store

iterator items*[Comps: tuple](store: var ArchetypeStore[Comps]): var ArchRow[Comps] =
    ## Iterates over the components in a view
    for row in store.compStore.items:
        yield row

func addLen*[Comps: tuple](store: var ArchetypeStore[Comps], len: var uint) =
    ## Accessor for the archetype of a store
    len += store.compStore.len

proc addLen*[Comps: tuple](
    store: var ArchetypeStore[Comps],
    len: var uint,
    predicate: proc(row: var Comps): bool {.fastcall, gcsafe, raises: [].},
) =
    ## Reads the length of an archetype store, using a predicate to determine whether to count a row
    for row in store.compStore.items:
        if predicate(row.components):
            len += 1

proc newSlot*[Comps: tuple](
    store: var ArchetypeStore[Comps],
    entityId: EntityId
): NewArchSlot[Comps] =
    ## Reserves a slot for storing a new component
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

proc getComps*[Comps: tuple](store: var ArchetypeStore[Comps], index: uint): ptr Comps =
    ## Return the components for an archetype
    addr store.compStore[index].components

proc del*(store: var ArchetypeStore, index: uint) =
    ## Return the components for an archetype
    discard store.compStore.del(index)

proc moveEntity*[FromArch: tuple, NewComps: tuple, ToArch: tuple](
    world: var World,
    entityIndex: ptr EntityIndex,
    fromArch: var ArchetypeStore[FromArch],
    toArch: var ArchetypeStore[ToArch],
    newValues: sink NewComps,
    combine: proc (existing: sink FromArch, newValues: sink NewComps, output: var ToArch): bool {.gcsafe, raises: [], fastcall.}
) {.gcsafe, raises: [].} =
    ## Moves the components for an entity from one archetype to another
    let deleted = fromArch.compStore.del(entityIndex.archetypeIndex)
    let existing = deleted.components
    let newSlot = newSlot[ToArch](toArch, entityIndex.entityId)
    var output: ToArch
    let success = combine(existing, newValues, output)
    assert(success, fmt"Unable to convert tuple from {$FromArch} with {$NewComps} to {$ToArch}")
    discard setComp(newSlot, output)
    entityIndex.archetype = toArch.archetype
    entityIndex.archetypeIndex = newSlot.index
