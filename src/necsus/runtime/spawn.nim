import entityId, world, archetypeStore, std/[options, macros, algorithm], ../util/[typeReader, nimNode]

type
    RawSpawn*[C: tuple] = proc(): NewArchSlot[C]
        ## A callback for populating a component with values

    Spawn*[C: tuple] = distinct RawSpawn[C]
        ## Describes a type that is able to create new entities. Where `C` is a tuple
        ## with all the components to initially attach to this entity. Does not return the new EntityId

    FullSpawn*[C: tuple] = distinct RawSpawn[C]
        ## Describes a type that is able to create new entities. Where `C` is a tuple
        ## with all the components to initially attach to this entity. Returns the new EntityId

proc beginSpawn*[Archs: enum, Comps: tuple](
    world: var World[Archs],
    store: var ArchetypeStore[Archs, Comps]
): NewArchSlot[Comps] {.inline, gcsafe, raises: [].} =
    ## Spawns an entity in this archetype
    var newEntity = world.newEntity
    result = store.newSlot(newEntity.entityId)
    newEntity.setArchetypeDetails(store.archetype, result.index)

func set*[C: tuple](spawn: Spawn[C], values: sink C) {.inline, raises: [].} =
    ## Spawns an entity with the given components
    discard setComp(RawSpawn[C](spawn)(), values)

proc set*[C: tuple](spawn: FullSpawn[C], values: sink C): EntityId {.inline.} =
    ## Spawns an entity with the given components
    setComp(RawSpawn[C](spawn)(), values)

macro buildTuple(values: varargs[untyped]): untyped =
    result = nnkTupleConstr.newTree()
    for elem in values: result.add(elem)

template with*[C: tuple](spawn: Spawn[C], values: varargs[typed]) =
    ## spawns the given values
    set(spawn, buildTuple(values))

template with*[C: tuple](spawn: FullSpawn[C], values: varargs[typed]): EntityId =
    ## spawns the given values
    set(spawn, buildTuple(values))

macro extend*(a, b: typedesc): typedesc =
    ## Combines two tuples to create a new tuple
    let tupleA = a.resolveTo({nnkTupleConstr}).get(a)
    tupleA.expectKind(nnkTupleConstr)

    let tupleB = b.resolveTo({nnkTupleConstr}).get(b)
    tupleB.expectKind(nnkTupleConstr)

    var children: seq[NimNode]
    for child in tupleA: children.add(child)
    for child in tupleB: children.add(child)
    children.sort(nimNode.cmp)

    result = nnkTupleConstr.newTree(children)
    result.copyLineInfo(a)