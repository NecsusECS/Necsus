import tables, sets, sequtils, archetype

export archetype

type
    ArchetypeBuilder*[T] = ref object
        ## A builder for creating a list of all known archetypes
        archetypes: HashSet[Archetype[T]]
        attachable: HashSet[Archetype[T]]
        detachable: HashSet[Archetype[T]]

proc newArchetypeBuilder*[T](): ArchetypeBuilder[T] =
    ## Creates a new ArchetypeBuilder
    result.new
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

    var workQueue = initHashSet[Archetype[T]]()
    var output = initHashSet[Archetype[T]]()

    # Add in all the baseline archetypes
    for archetype in builder.archetypes.items:
        workQueue.incl(archetype)

    while workQueue.card > 0:
        let next = workQueue.pop
        if next.len > 0 and not output.containsOrIncl(next):

            # Create all variations of existing archetypes for when a new component combination is attached
            for attachable in builder.attachable:
                let variant = next + attachable
                if variant notin output:
                    workQueue.incl(variant)

            # Create all variations of existing archetypes for when a new component combination is detached
            for detachable in builder.detachable.items:
                if next.containsAllOf(detachable):
                    let variant = next - detachable
                    if variant notin output:
                        workQueue.incl(variant)

    result = newArchetypeSet(output.items.toSeq)
