import tables, sets, sequtils, archetype, algorithm, ../util/bits

export archetype, bits.hash, bits.`$`, bits.`==`

type
    AttachableValues = tuple[archetype: Bits, filter: BitsFilter]

    ArchetypeBuilder*[T] = ref object
        ## A builder for creating a list of all known archetypes
        lookup: seq[T]
        archetypes: HashSet[Bits]
        attachable: HashSet[AttachableValues]
        detachable: HashSet[Bits]

proc newArchetypeBuilder*[T](): ArchetypeBuilder[T] =
    ## Creates a new ArchetypeBuilder
    ArchetypeBuilder[T](
        lookup: newSeq[T](256),
        archetypes: initHashSet[Bits](),
        attachable: initHashSet[AttachableValues](),
        detachable: initHashSet[Bits](),
    )

proc asBits[T](builder: var ArchetypeBuilder[T], values: openarray[T]): Bits =
    result = Bits()
    for value in values:
        if builder.lookup.len < value.uniqueId.int:
            builder.lookup.setLen(value.uniqueId * 2)
        builder.lookup[value.uniqueId] = value
        result.incl(value.uniqueId)

proc filter*[T](builder: var ArchetypeBuilder[T], mustContain: openarray[T], mustExclude: openarray[T]): BitsFilter =
    newFilter(builder.asBits(mustContain), builder.asBits(mustExclude))

proc define*[T](builder: var ArchetypeBuilder[T], values: openarray[T]) =
    ## Adds a new archetype with specific values
    builder.archetypes.incl(asBits(builder, values))

proc attachable*[T](builder: var ArchetypeBuilder[T], values: openarray[T], filter: BitsFilter) =
    ## Describes components that can be attached to entities to create new archetypes
    builder.attachable.incl((asBits(builder, values), filter))

proc detachable*[T](builder: var ArchetypeBuilder[T], values: openarray[T]) =
    ## Describes components that can be detached from entities to create new archetypes
    builder.detachable.incl(asBits(builder, values))

proc process[T](builder: ArchetypeBuilder[T], next: Bits, output: var HashSet[Bits], workQueue: var HashSet[Bits]) =
    if next.card > 0 and next notin output:
        output.incl(next)

        # Create all variations of existing archetypes for when a new component combination is attached
        for attachable in builder.attachable:
            if next.matches(attachable.filter):
                let variant = next + attachable.archetype
                if variant notin output:
                    workQueue.incl(variant)

        # Create all variations of existing archetypes for when a new component combination is detached
        for detachable in builder.detachable.items:
            if detachable < next:
                let variant = next - detachable
                if variant notin output:
                    workQueue.incl(variant)

proc build*[T](builder: ArchetypeBuilder[T]): ArchetypeSet[T] =
    ## Constructs the final set of archetypes

    var workQueue = initHashSet[Bits](256)
    var output = initHashSet[Bits](256)

    # Add in all the baseline archetypes
    for archetype in builder.archetypes.items:
        builder.process(archetype, output, workQueue)

    while workQueue.len > 0:
        builder.process(workQueue.pop, output, workQueue)

    var archetypes: seq[Archetype[T]]
    for bits in output:
        var values: seq[T]
        for bit in bits.items:
            values.add(builder.lookup[bit])
        values.sort()
        archetypes.add(newArchetype(values))

    result = newArchetypeSet(archetypes)
