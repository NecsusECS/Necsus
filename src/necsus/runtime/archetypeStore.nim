import world, entityId, ../util/blockstore

type
    ArchRow[Comps: tuple] = object
        ## A row of data stored about an entity that matches a specific archetype
        entityId: EntityId
        components: Comps

    ArchetypeStore[Archs: enum, Comps: tuple] = ref object
        ## Stores a specific archetype shape
        archetype: Archs
        compStore: BlockStore[ArchRow[Comps]]

    ArchView*[ViewComps: tuple] = object
        ## An object able to iterate over an archetype using a specific view of the data
        buildIterator: proc(): iterator(): (EntityId, ViewComps)

proc newArchetypeStore*[Archs: enum, Comps: tuple](
    archetype: Archs,
    initialSize: SomeInteger
): ArchetypeStore[Archs, Comps] =
    ## Creates a new storage block for an archetype
    result.new
    result.compStore = newBlockStore[ArchRow[Comps]](initialSize)
    result.archetype = archetype

proc spawn*[Archs: enum, Comps: tuple](
    world: var World[Archs],
    store: ArchetypeStore[Archs, Comps],
    components: sink Comps
): EntityId {.inline.} =
    ## Spawns an entity in this archetype
    return newEntity[Archs](world, store.archetype) do (id: EntityId) -> uint:
        store.compStore.push(ArchRow[Comps](entityId: id, components: components))

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
