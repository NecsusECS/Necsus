import entityId, world, archetypeStore, std/macros

type
    RawSpawn*[C: tuple] = ref object
        ## A callback for populating a component with values
        world: World
        store: ptr ArchetypeStore[C]

    Spawn*[C: tuple] = distinct RawSpawn[C]
        ## Describes a type that is able to create new entities. Where `C` is a tuple
        ## with all the components to initially attach to this entity. Does not return the new EntityId

    FullSpawn*[C: tuple] = distinct RawSpawn[C]
        ## Describes a type that is able to create new entities. Where `C` is a tuple
        ## with all the components to initially attach to this entity. Returns the new EntityId

proc newSpawn*[Comps: tuple](world: World, store: ptr ArchetypeStore[Comps]): RawSpawn[Comps] =
    return RawSpawn[Comps](world: world, store: store)

proc beginSpawn*[Comps: tuple](
    world: var World,
    store: ptr ArchetypeStore[Comps]
): NewArchSlot[Comps] {.inline, gcsafe, raises: [].} =
    ## Spawns an entity in this archetype
    var newEntity = world.newEntity
    result = store.newSlot(newEntity.entityId)
    newEntity.setArchetypeDetails(store.archetype, result.index)

func set*[C: tuple](spawn: Spawn[C], values: sink C) {.inline, raises: [].} =
    ## Spawns an entity with the given components
    var world = RawSpawn[C](spawn).world
    var slot = beginSpawn(world, RawSpawn[C](spawn).store)
    discard setComp(slot, values)

proc set*[C: tuple](spawn: FullSpawn[C], values: sink C): EntityId {.inline.} =
    ## Spawns an entity with the given components
    var store = RawSpawn[C](spawn).store
    var world = RawSpawn[C](spawn).world
    var slot = beginSpawn(world, store)
    return setComp(slot, values)

macro buildTuple(values: varargs[untyped]): untyped =
    result = nnkTupleConstr.newTree()
    for elem in values: result.add(elem)

template with*[C: tuple](spawn: Spawn[C], values: varargs[typed]) =
    ## spawns the given values
    set(spawn, buildTuple(values))

template with*[C: tuple](spawn: FullSpawn[C], values: varargs[typed]): EntityId =
    ## spawns the given values
    set(spawn, buildTuple(values))
