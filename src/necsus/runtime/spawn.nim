import entityId, world, archetypeStore, macros

type
    RawSpawn*[C: tuple] = proc(): NewArchSlot[C]
        ## A callback for populating a component with values

    Spawn*[C: tuple] = distinct RawSpawn[C]
        ## Describes a type that is able to create new entities. Where `C` is a tuple
        ## with all the components to initially attach to this entity

proc beginSpawn*[Archs: enum, Comps: tuple](
    world: var World[Archs],
    store: var ArchetypeStore[Archs, Comps]
): NewArchSlot[Comps] {.inline.} =
    ## Spawns an entity in this archetype
    var newEntity = world.newEntity
    result = store.newSlot(newEntity.entityId)
    newEntity.setArchetypeDetails(store.archetype, result.index)

proc set*[C: tuple](spawn: Spawn[C], values: C): EntityId {.inline.} =
    ## Spawns an entity with the given components
    setComp(RawSpawn[C](spawn)(), values)

macro buildTuple(values: varargs[untyped]): untyped =
    result = nnkTupleConstr.newTree()
    for elem in values: result.add(elem)

template with*[C: tuple](spawn: Spawn[C], values: varargs[typed]): EntityId =
    ## spawns the given values
    set(spawn, buildTuple(values))
