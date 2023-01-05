import tables, sets, hashes, strutils, sequtils, algorithm, componentDef, macros

type
    Archetype*[T] = ref object
        ## A archetype of values that can be stored together
        values: seq[T]
        lookup: Table[T, int]

    ArchetypeSet*[T] = object
        ## A set of all known archetypes
        archetypes: HashSet[Archetype[T]]

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

proc contains*[T](archetype: Archetype[T], value: T): bool =
    ## Whether an archetype contains all the given value
    archetype.lookup.hasKey(value)

proc containsAllOf*[T](archetype: Archetype[T], other: Archetype[T]): bool =
    ## Whether an archetype contains all the given values
    other.values.allIt(it in archetype)

proc `-`*[T](archetype: Archetype[T], other: Archetype[T]): Archetype[T] =
    ## Removes components in an archetype
    archetype.values.filterIt(not other.lookup.hasKey(it)).newArchetype

proc `+`*[T](archetype: Archetype[T], other: Archetype[T]): Archetype[T] =
    ## Joins together two archetypes
    concat(archetype.values, other.values).newArchetype

proc len*[T](archetype: Archetype[T]): auto = archetype.values.len
    ## The number of values in this archetype

proc name*(archetype: Archetype[ComponentDef]): string =
    ## Stringify a Archetype
    generateName(archetype.values)

proc ident*(archetype: Archetype[ComponentDef]): NimNode =
    ## Creates a variable for referencing an archetype store
    ident("archetype_" & archetype.name)

proc asStorageTuple*(archetype: Archetype[ComponentDef]): NimNode =
    ## Creates the tuple type for storing an archetype
    result = nnkTupleConstr.newTree()
    for component in archetype.values: result.add(component.ident)

iterator items*[T](archetype: Archetype[T]): T =
    ## Produces all the archetype values
    for value in archetype.values: yield value

proc newArchetypeSet*[T](values: openarray[Archetype[T]]): ArchetypeSet[T] =
    ## Creates a set of archetypes
    result.archetypes = values.toHashSet

iterator items*[T](archetypes: ArchetypeSet[T]): Archetype[T] =
    ## Produces all the archetypes
    for archetype in items(archetypes.archetypes):
        yield archetype

proc `[]`*[T](archetypes: ArchetypeSet[T], search: openarray[T]): Archetype[T] =
    ## Returns the archetype containing the given values
    result = newArchetype(search)
    if result notin archetypes.archetypes:
        raise newException(KeyError, "Could not find archetype: " & join(search, ", "))
