import tables, sets, sequtils, archetype

export archetype

type
    ArchetypeTable[T] = object
        ## A table for normalizing archetypes as they are added
        lookup: Table[HashSet[T], Archetype[T]]

    ArchetypeBuilder*[T] = object
        ## A builder for creating a list of all known archetypes
        archetypes: ArchetypeTable[T]
        attachable: HashSet[Archetype[T]]
        detachable: HashSet[Archetype[T]]

proc init[T](table: var ArchetypeTable[T]) =
    table.lookup = initTable[HashSet[T], Archetype[T]]()

proc addIfAbsent[T](table: var ArchetypeTable[T], arch: Archetype[T]): bool =
    ## Adds an archetype if it doesnt exist in the table already. Returns true if the archetype wasn't in the table
    let asSet = arch.asHashSet
    result = asSet notin table.lookup or table.lookup[asSet] == arch
    if result:
        table.lookup[asSet] = arch

proc add[T](table: var ArchetypeTable[T], arch: Archetype[T]) =
    ## Add an archetype, assuming it hasn't been added before
    discard table.addIfAbsent(arch)

iterator items[T](table: ArchetypeTable[T]): Archetype[T] =
    for _, value in table.lookup.pairs: yield value

proc len[T](table: ArchetypeTable[T]): int = table.lookup.len

proc newArchetypeBuilder*[T](): ArchetypeBuilder[T] =
    ## Creates a new ArchetypeBuilder
    result.archetypes.init()
    result.attachable.init()
    result.detachable.init()

proc define*[T](builder: var ArchetypeBuilder[T], values: openarray[T]) =
    ## Adds a new archetype with specific values
    builder.archetypes.add(values.newArchetype)

proc attachable*[T](builder: var ArchetypeBuilder[T], values: openarray[T]) =
    ## Describes components that can be attached to entities to create new archetypes
    builder.attachable.incl(values.newArchetype)

proc detachable*[T](builder: var ArchetypeBuilder[T], values: openarray[T]) =
    ## Describes components that can be detached from entities to create new archetypes
    builder.detachable.incl(values.newArchetype)

proc build*[T](builder: ArchetypeBuilder[T]): ArchetypeSet[T] =
    ## Constructs the final set of archetypes

    var resultArchetypes: ArchetypeTable[T]
    resultArchetypes.init()

    # Add in all the baseline archetypes
    for archetype in builder.archetypes.items:
        resultArchetypes.add(archetype)

    # Now we need to modify those archetypes with attachables and detachables
    # to cover any transitions between archetypes that might be possible. We keep
    # modifying the set of archetypes until we reach a stable state
    var size = 0
    while resultArchetypes.len != size:
        size = resultArchetypes.len

        # Collect any new archetype variations that need to be considered
        var newArchetypes = newSeq[Archetype[T]]()
        for archetype in resultArchetypes.items:

            # Create all variations of existing archetypes for when a new component combination is attached
            for attachable in builder.attachable.items:
                newArchetypes.add(archetype + attachable)

            # Create all variations of existing archetypes for when a new component combination is detached
            for detachable in builder.detachable.items:
                if archetype.containsAllOf(detachable):
                    newArchetypes.add(archetype - detachable)

        for newArchetype in newArchetypes:
            if newArchetype.len > 0:
                discard resultArchetypes.addIfAbsent(newArchetype)

    result = newArchetypeSet(resultArchetypes.items.toSeq)
