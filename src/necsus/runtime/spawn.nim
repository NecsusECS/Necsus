import entityId, world, archetypeStore, ../util/tools, std/macros

type
    RawSpawn*[C: tuple] = ref object
        ## A callback for populating a component with values
        app: pointer
        callback: proc(app: pointer, value: sink C): EntityId {.fastcall, raises: [], gcsafe.}

    Spawn*[C: tuple] = distinct RawSpawn[C]
        ## Describes a type that is able to create new entities. Where `C` is a tuple
        ## with all the components to initially attach to this entity. Does not return the new EntityId

    FullSpawn*[C: tuple] = distinct RawSpawn[C]
        ## Describes a type that is able to create new entities. Where `C` is a tuple
        ## with all the components to initially attach to this entity. Returns the new EntityId

proc asFullSpawn*[Comps](rawSpawn: RawSpawn[Comps]): FullSpawn[Comps] = FullSpawn[Comps](rawSpawn)

proc asSpawn*[Comps](rawSpawn: RawSpawn[Comps]): Spawn[Comps] = Spawn[Comps](rawSpawn)

proc newSpawn*[Comps: tuple](
    app: pointer,
    callback: proc(app: pointer, value: sink Comps): EntityId {.fastcall, raises: [], gcsafe.}
): RawSpawn[Comps] =
    return RawSpawn[Comps](app: app, callback: callback)

proc beginSpawn*[Comps: tuple](
    world: var World,
    store: ptr ArchetypeStore[Comps]
): NewArchSlot[Comps] {.inline, gcsafe, raises: [].} =
    ## Spawns an entity in this archetype
    var newEntity = world.newEntity
    result = store.newSlot(newEntity.entityId)
    newEntity.setArchetypeDetails(store.archetype, result.index)

when isSinkMemoryCorruptionFixed():
    proc set[C: tuple](spawn: RawSpawn[C], values: sink C): EntityId {.raises: [], inline.} =
        return spawn.callback(spawn.app, values)
else:
    proc set[C: tuple](spawn: RawSpawn[C], values: C): EntityId {.raises: [], inline.} =
        return spawn.callback(spawn.app, values)

proc set*[C: tuple](spawn: Spawn[C], values: sink C) {.raises: [], inline.} =
    ## Spawns an entity with the given components
    discard set(RawSpawn[C](spawn), values)

proc set*[C: tuple](spawn: FullSpawn[C], values: sink C): EntityId {.inline.} =
    ## Spawns an entity with the given components
    return set(RawSpawn[C](spawn), values)

macro buildTuple(values: varargs[untyped]): untyped =
    result = nnkTupleConstr.newTree()
    for elem in values: result.add(elem)

template with*[C: tuple](spawn: Spawn[C], values: varargs[typed]) =
    ## spawns the given values
    set(spawn, buildTuple(values))

template with*[C: tuple](spawn: FullSpawn[C], values: varargs[typed]): EntityId =
    ## spawns the given values
    set(spawn, buildTuple(values))
