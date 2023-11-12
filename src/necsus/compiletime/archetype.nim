import tables, sets, hashes, strutils, sequtils, componentDef, macros, algorithm

type
    Archetype*[T] = ref object
        ## A archetype of values that can be stored together
        values: seq[T]
        name*: string
        identName: string
        cachedHash: Hash

    ArchetypeSet*[T] = object
        ## A set of all known archetypes
        archetypes: HashSet[Archetype[T]]

    UnsortedArchetype* = object of Defect
        ## Thrown when an archetype is out of sorted order

proc generateName(values: openarray[string]): string = values.join("_")

proc newArchetype*[T](values: openarray[T]): Archetype[T] =
    ## Create an archetype

    if not values.isSorted:
        let correct = values.sorted().deduplicate(isSorted = true).join(", ")
        raise newException(UnsortedArchetype, "Archetype must be in sorted order. Correct order is: " & correct)

    result.new
    result.values = values.toSeq.deduplicate(isSorted = true)
    result.name = generateName(result.values)
    result.identName = "archetype_" & result.name
    result.cachedHash = hash(result.values)

proc hash*[T](archetype: Archetype[T]): Hash = archetype.cachedHash
    ## Create a hash describing a archetype

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
    archetype.values.binarySearch(value) >= 0

proc indexOf*[T](archetype: Archetype[T], value: T): int =
    ## Whether an archetype contains all the given value
    result = archetype.values.binarySearch(value)
    assert(result != -1, "Value is not in archetype: " & $value)

proc containsAllOf*[T](archetype: Archetype[T], other: openarray[T]): bool =
    ## Whether an archetype contains all the given values
    other.allIt(it in archetype)

proc containsAllOf*[T](archetype: Archetype[T], other: Archetype[T]): bool =
    ## Whether an archetype contains all the given values
    containsAllOf(archetype, other.values)

proc `-`*[T](archetype: Archetype[T], other: Archetype[T]): Archetype[T] =
    ## Removes components in an archetype
    archetype.values.filterIt(it notin other).newArchetype

proc `-`*[T](archetype: Archetype[T], other: openarray[T]): Archetype[T] =
    ## Adds values to an archetype
    archetype.values.filterIt(it notin other).sorted().newArchetype

proc `+`*[T](archetype: Archetype[T], other: openarray[T]): Archetype[T] =
    ## Adds values to an archetype
    concat(archetype.values, other.toSeq).sorted().newArchetype

proc `+`*[T](archetype: Archetype[T], other: Archetype[T]): Archetype[T] =
    ## Joins together two archetypes
    archetype + other.values

proc len*[T](archetype: Archetype[T]): auto = archetype.values.len
    ## The number of values in this archetype

proc asHashSet*[T](archetype: Archetype[T]): auto = toHashSet(archetype.values)
    ## Create a hash set from this archetype

proc ident*(archetype: Archetype[ComponentDef]): NimNode = archetype.identName.ident
    ## Creates a variable for referencing an archetype store

proc asStorageTuple*(archetype: Archetype[ComponentDef]): NimNode =
    ## Creates the tuple type for storing an archetype
    result = nnkTupleConstr.newTree()
    for component in archetype.values: result.add(component.ident)

iterator items*[T](archetype: Archetype[T]): T =
    ## Produces all the archetype values
    for value in archetype.values: yield value

proc values*[T](archetype: Archetype[T]): seq[T] = archetype.values
    ## Produces all the archetype values


proc newArchetypeSet*[T](values: openarray[Archetype[T]]): ArchetypeSet[T] =
    ## Creates a set of archetypes
    result.archetypes = values.toHashSet

proc len*[T](archetypes: ArchetypeSet[T]): int = archetypes.archetypes.card

iterator items*[T](archetypes: ArchetypeSet[T]): Archetype[T] =
    ## Produces all the archetypes
    for archetype in items(archetypes.archetypes):
        yield archetype
