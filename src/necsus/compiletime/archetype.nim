import tables, sets, hashes, strutils, sequtils, algorithm

type
    Archetype*[T] = ref object
        ## A archetype of values that can be stored together
        values: seq[T]
        lookup: Table[T, int]

    ArchetypeSet*[T] = object
        ## A set of all known archetypes
        archetypes: seq[Archetype[T]]

proc newArchetype*[T](values: openarray[T]): Archetype[T] =
    ## Create an archetype
    result.new
    result.values = values.toSeq.sorted.deduplicate
    result.lookup = initTable[T, int](result.values.len)
    for i, value in result.values:
        result.lookup[value] = i

proc hash*[T](archetype: Archetype[T]): Hash =
    ## Create a hash describing a archetype
    hash(archetype.values)

proc `==`*[T](a, b: Archetype[T]): bool =
    ## Determine archetype equality
    a.values == b.values

proc `$`*[T](archetype: Archetype[T]): string =
    ## Stringify a Archetype
    result.add("{")
    result.add(archetype.values.items.toSeq.join(", "))
    result.add("}")

proc containsAllOf*[T](archetype: Archetype[T], other: Archetype[T]): bool =
    ## Whether an archetype contains all the given values
    other.values.allIt(archetype.lookup.hasKey(it))

proc `-`*[T](archetype: Archetype[T], other: Archetype[T]): Archetype[T] =
    ## Removes components in an archetype
    archetype.values.filterIt(not other.lookup.hasKey(it)).newArchetype

proc `+`*[T](archetype: Archetype[T], other: Archetype[T]): Archetype[T] =
    ## Joins together two archetypes
    concat(archetype.values, other.values).newArchetype

proc len*[T](archetype: Archetype[T]): auto = archetype.values.len
    ## The number of values in this archetype

proc newArchetypeSet*[T](values: openarray[Archetype[T]]): ArchetypeSet[T] =
    ## Creates a set of archetypes
    result.archetypes = values.toSeq.sorted

iterator items*[T](archetypes: ArchetypeSet[T]): Archetype[T] =
    ## Produces all the archetypes
    for archetype in items(archetypes.archetypes):
        yield archetype
