import entityId, world, archetypeStore, macros

type
    RawSpawn*[C: tuple] = proc(): NewArchSlot[C]
        ## A callback for populating a component with values

    Spawn*[C: tuple] = ref object
        ## Describes a type that is able to create new entities. Where `C` is a tuple
        ## with all the components to initially attach to this entity
        rawSpawn: RawSpawn[C]

proc newSpawn*[C: tuple](rawSpawn: RawSpawn[C]): Spawn[C] =
    ## Creates a new spawn instance
    result.new
    result.rawSpawn = rawSpawn

proc beginSpawn*[Archs: enum, Comps: tuple](
    world: var World[Archs],
    store: var ArchetypeStore[Archs, Comps]
): NewArchSlot[Comps] {.inline.} =
    ## Spawns an entity in this archetype
    var newEntity = world.newEntity
    result = store.newSlot(newEntity.entityId)
    newEntity.setArchetypeDetails(store.archetype, result.index)

template set*[C: tuple](spawn: Spawn[C], values: C): EntityId =
    ## Spawns an entity with the given components
    setComp(spawn.rawSpawn(), values)

macro buildTuple(values: varargs[untyped]): untyped =
    result = nnkTupleConstr.newTree()
    for elem in values: result.add(elem)

template with*[C: tuple](spawn: Spawn[C], values: varargs[typed]): EntityId =
    ## spawns the given values
    set(spawn, buildTuple(values))
