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
        of true:
            detach: Bits
            optDetach: Bits
        of false:
            discard

    ArchetypeBuilder*[T] = ref object
        ## A builder for creating a list of all known archetypes
        lookup: seq[T]
        archetypes: HashSet[Bits]
        actions: HashSet[BuilderAction]
        accessories: Bits

    ArchetypeAccum = ref object
        ## Used during the final calculation as an accumulator for the full set of archetypes
        seen: HashSet[Bits]
        workQueue: HashSet[Bits]
        output: Table[Bits, Bits]

proc newArchetypeBuilder*[T](): ArchetypeBuilder[T] =
    ## Creates a new ArchetypeBuilder
    ArchetypeBuilder[T](
        lookup: newSeq[T](256),
        archetypes: initHashSet[Bits](),
        actions: initHashSet[BuilderAction](),
        accessories: Bits(),
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

proc detachable*[T](builder: var ArchetypeBuilder[T], values: openarray[T], optional: openarray[T] = []) =
    ## Describes components that can be detached from entities to create new archetypes
    builder.actions.incl(
        BuilderAction(
            detaching: true,
            detach: asBits(builder, values),
            optDetach: asBits(builder, optional)
        )
    )

proc accessory*[T](builder: var ArchetypeBuilder[T], value: T) =
    ## Marks that a value is an accessory and should not, itself, cause the creation of a new archetype
    builder.accessories.incl(value.uniqueId)

proc attachDetach*[T](
    builder: var ArchetypeBuilder[T],
    attach: openarray[T],
    detach: openarray[T],
    optDetach: openarray[T] = [],
    filter: BitsFilter = builder.filter([], [])
) =
    ## Describes components that can be attached to entities to create new archetypes
    builder.actions.incl(
        BuilderAction(
            filtered: true, filter: filter,
            attaching: true, attach: asBits(builder, attach),
            detaching: true, detach: asBits(builder, detach), optDetach: asBits(builder, optDetach)
        )
    )


proc addWork[T](builder: ArchetypeBuilder[T], source: Bits, accum: var ArchetypeAccum) =
    for action in builder.actions:
        if not action.filtered or source.matches(action.filter):
            var variant = source
            if action.attaching:
                variant = variant + action.attach
            if action.detaching:
                if action.detach <= variant:
                    variant = variant - action.detach
                variant = variant - action.optDetach
            if variant notin accum.seen:
                accum.workQueue.incl(variant)

proc process[T](builder: ArchetypeBuilder[T], next: Bits, accum: var ArchetypeAccum) =
    if next.card > 0 and next notin accum.seen:

        # The minimal set of components, minus all the accessory components
        var minValues = next - builder.accessories

        # Makes sure the registerd output includes any new accessories
        if minValues in accum.output:
            accum.output[minValues] = accum.output[minValues] + next
        else:
            accum.output[minValues] = next

        accum.seen.incl(next)
        builder.addWork(next, accum)

proc build*[T](builder: ArchetypeBuilder[T]): ArchetypeSet[T] =
    ## Constructs the final set of archetypes

    var accum = ArchetypeAccum(
        workQueue: initHashSet[Bits](256),
        seen: initHashSet[Bits](256),
        output: initTable[Bits, Bits](256),
    )

    # Add in all the baseline archetypes
    for archetype in builder.archetypes.items:
        builder.process(archetype, accum)

    while accum.workQueue.len > 0:
        builder.process(accum.workQueue.pop, accum)

    var archetypes: seq[Archetype[T]]
    for _, bits in accum.output:
        var values: seq[T]
        for bit in bits.items:
            values.add(builder.lookup[bit])
        values.sort()
        archetypes.add(newArchetype(values, builder.accessories))

    result = newArchetypeSet(archetypes)
