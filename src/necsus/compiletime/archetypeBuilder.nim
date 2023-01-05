import tables, sets, sequtils, archetype

export archetype

type
    ArchetypeBuilder*[T] = object
        ## A builder for creating a list of all known archetypes
        archetypes: HashSet[Archetype[T]]
        attachable: HashSet[Archetype[T]]
        detachable: HashSet[Archetype[T]]

proc newArchetypeBuilder*[T](): ArchetypeBuilder[T] =
    ## Creates a new ArchetypeBuilder
    result.archetypes.init()
    result.attachable.init()
    result.detachable.init()

proc define*[T](builder: var ArchetypeBuilder[T], values: openarray[T]) =
    ## Adds a new archetype with specific values
    builder.archetypes.incl(values.newArchetype)

proc attachable*[T](builder: var ArchetypeBuilder[T], values: openarray[T]) =
    ## Describes components that can be attached to entities to create new archetypes
    builder.attachable.incl(values.newArchetype)

proc detachable*[T](builder: var ArchetypeBuilder[T], values: openarray[T]) =
    ## Describes components that can be detached from entities to create new archetypes
    builder.detachable.incl(values.newArchetype)

proc build*[T](builder: ArchetypeBuilder[T]): ArchetypeSet[T] =
    ## Constructs the final set of archetypes

    var resultArchetypes = initHashSet[Archetype[T]]()

    # Add in all the baseline archetypes
    for archetype in items(builder.archetypes):
        resultArchetypes.incl(archetype)

    # Now we need to modify those archetypes with attachables and detachables
    # to cover any transitions between archetypes that might be possible. We keep
    # modifying the set of archetypes until we reach a stable state
    var size = 0
    while resultArchetypes.card != size:
        size = resultArchetypes.card

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
                resultArchetypes.incl(newArchetype)

    result = newArchetypeSet(resultArchetypes.items.toSeq)
