import tables, sets, sequtils, archetype, algorithm, ../util/bits, hashes

export archetype, bits.hash, bits.`$`, bits.`==`

type
    BuilderAction = object
        case filtered: bool
        of true: filter: BitsFilter
        of false: discard

        case attaching: bool
        of true: attach: Bits
        of false: discard

        case detaching: bool
        of true: detach: Bits
        of false: discard

    ArchetypeBuilder*[T] = ref object
        ## A builder for creating a list of all known archetypes
        lookup: seq[T]
        archetypes: HashSet[Bits]
        actions: HashSet[BuilderAction]

proc newArchetypeBuilder*[T](): ArchetypeBuilder[T] =
    ## Creates a new ArchetypeBuilder
    ArchetypeBuilder[T](
        lookup: newSeq[T](256),
        archetypes: initHashSet[Bits](),
        actions: initHashSet[BuilderAction](),
    )

proc hash*(action: BuilderAction): Hash =
    if action.filtered:
        result = action.filter.hash
    if action.attaching:
        result = result !& action.attach.hash
    if action.detaching:
        result = result !& action.detach.hash

proc `==`*(a, b: BuilderAction): bool =
    if a.filtered != b.filtered:
        return false
    elif a.filtered and a.filtered != b.filtered:
        return false
    elif a.attaching == b.attaching:
        return false
    elif a.attaching and a.attach != b.attach:
        return false
    elif a.detaching == b.detaching:
        return false
    elif a.detaching and a.detach != b.detach:
        return false

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
    builder.actions.incl(
        BuilderAction(filtered: true, filter: filter, attaching: true, attach: asBits(builder, values)))

proc detachable*[T](builder: var ArchetypeBuilder[T], values: openarray[T]) =
    ## Describes components that can be detached from entities to create new archetypes
    builder.actions.incl(BuilderAction(detaching: true, detach: asBits(builder, values)))

proc attachDetach*[T](
    builder: var ArchetypeBuilder[T],
    attach: openarray[T],
    detach: openarray[T],
    filter: BitsFilter = builder.filter([], [])
) =
    ## Describes components that can be attached to entities to create new archetypes
    builder.actions.incl(
        BuilderAction(
            filtered: true, filter: filter,
            attaching: true, attach: asBits(builder, attach),
            detaching: true, detach: asBits(builder, detach)
        )
    )

proc process[T](builder: ArchetypeBuilder[T], next: Bits, output: var HashSet[Bits], workQueue: var HashSet[Bits]) =
    if next.card > 0 and next notin output:
        output.incl(next)

        for action in builder.actions:
            if not action.filtered or next.matches(action.filter):
                var variant = next
                if action.attaching:
                    variant = variant + action.attach
                if action.detaching:
                    variant = variant - action.detach
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
