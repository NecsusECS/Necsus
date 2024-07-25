import std/[tables, sets, hashes, strutils, sequtils, macros, algorithm, macrocache]
import componentDef, ../util/bits, ../runtime/world

type
    Archetype*[T] = ref object
        ## A archetype of values that can be stored together
        values: seq[T]
        name*: string
        identName: string
        cachedHash: Hash
        bitset*: Bits
        id: ArchetypeId

    ArchetypeSet*[T] = ref object
        ## A set of all known archetypes
        archetypes: HashSet[Archetype[T]]

    UnsortedArchetype* = object of Defect
        ## Thrown when an archetype is out of sorted order

proc generateName(values: openarray[string]): string = values.join("_")

when NimMajor >= 2:
    const nextId = CacheCounter("NextArchetypeId")
    const ids = CacheTable("ArchetypeIds")
else:
    import std/tables
    var nextId {.compileTime.} = 0
    var ids {.compileTime.} = initTable[string, NimNode]()
    proc value(num: int): int {.inline.} = num

proc getId(name: string): ArchetypeId =
    ## Returns a unique ID for an archetype
    if name in ids:
        return ArchetypeId(ids[name].intVal)
    else:
        let newId = nextId.value
        nextId.inc
        ids[name] = newId.newLit
        return ArchetypeId(newId)

proc newArchetype*[T](values: openarray[T]): Archetype[T] =
    ## Create an archetype

    var bits = Bits()

    var verified: seq[T]
    var previous: T
    for i, value in values:
        if i > 0 and value < previous:
            let correct = values.sorted().join(", ")
            raise newException(UnsortedArchetype, "Archetype must be in sorted order. Correct order is: " & correct)
        elif i == 0 or previous != value:
            verified.add(value)
            bits.incl(value.uniqueId)
        previous = value

    let name = generateName(verified)

    return Archetype[T](
        values: verified,
        name: name,
        identName: "archetype_" & name,
        cachedHash: hash(verified),
        bitset: bits,
        id: name.getId,
    )

proc readableName*(arch: Archetype[ComponentDef]): string = arch.values.mapIt(it.readableName).join("_")
    ## Returns a readable name that describes an archetype

proc hash*[T](archetype: Archetype[T]): Hash = archetype.cachedHash
    ## Create a hash describing a archetype

proc `==`*[T](a, b: Archetype[T]): bool =
    ## Determine archetype equality
    a.bitset == b.bitset

proc `$`*[T](archetype: Archetype[T]): string =
    ## Stringify a Archetype
    result.add("{")
    result.add(archetype.values.items.toSeq.join(", "))
    result.add("}")

proc contains*[T](archetype: Archetype[T], value: T): bool =
    ## Whether an archetype contains all the given value
    value.uniqueId in archetype.bitset

proc indexOf*[T](archetype: Archetype[T], value: T): int =
    ## Whether an archetype contains all the given value
    result = archetype.values.binarySearch(value)
    assert(result != -1, "Value is not in archetype: " & $value)

proc containsAllOf*[T](archetype: Archetype[T], others: openarray[T]): bool =
    ## Whether an archetype contains all the given values
    for other in others:
        if other notin archetype:
            return false
    return true

proc containsAllOf*[T](archetype: Archetype[T], other: Archetype[T]): bool =
    ## Whether an archetype contains all the given values
    containsAllOf(archetype, other.values)

proc removeAndAdd*[T](archetype: Archetype[T], remove: Bits, add: openarray[T]): Archetype[T] =
    var accum: seq[T]
    for value in archetype:
        if value.uniqueId notin remove:
            accum.add(value)
    if add.len > 0:
        for value in add:
            if value notin archetype:
                accum.add(value)
        accum.sort()
    return newArchetype(accum)

proc `-`*[T](archetype: Archetype[T], other: Archetype[T]): Archetype[T] =
    ## Removes components in an archetype
    archetype.values.filterIt(it notin other).newArchetype

proc `-`*[T](archetype: Archetype[T], other: openarray[T]): Archetype[T] =
    ## Adds values to an archetype
    return if other.len == 0: archetype else: archetype.values.filterIt(it notin other).sorted().newArchetype

proc `+`*[T](archetype: Archetype[T], other: openarray[T]): Archetype[T] =
    ## Adds values to an archetype
    return if other.len == 0: archetype else: concat(archetype.values, other.toSeq).sorted().newArchetype

proc `+`*[T](archetype: Archetype[T], other: Archetype[T]): Archetype[T] =
    ## Joins together two archetypes
    return if archetype == other.archetype: archetype else: archetype + other.values

proc len*[T](archetype: Archetype[T]): auto = archetype.values.len
    ## The number of values in this archetype

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

when NimMajor >= 2:
    const archetypeSymbols = CacheTable("NecsusArchetypeIdSymbols")
else:
    var archetypeSymbols {.compileTime.} = initTable[string, NimNode]()

proc idSymbol*[T](archetype: Archetype[T]): NimNode =
    ## Returns a unique symbol containing an ID for this archetype
    if archetype.name notin archetypeSymbols:
        archetypeSymbols[archetype.name] = genSym(nskConst, "archetypeId")
    return archetypeSymbols[archetype.name]

when NimMajor >= 2:
    const archetypeSymbolsDefined = CacheTable("NecsusArchetypeIdSymbolsDefined")
else:
    var archetypeSymbolsDefined {.compileTime.} = initTable[string, NimNode]()

proc archArchSymbolDef*[T](archetype: Archetype[T]): NimNode =
    ## Builds the code for defining an archetype symbol
    if archetype.name in archetypeSymbolsDefined:
        return newStmtList()

    archetypeSymbolsDefined[archetype.name] = true.newLit
    let symbol = archetype.idSymbol
    let num = archetype.id
    return quote:
        const `symbol` = ArchetypeId(`num`)

proc newArchetypeSet*[T](values: openarray[Archetype[T]]): ArchetypeSet[T] =
    ## Creates a set of archetypes
    result.new
    result.archetypes = values.toHashSet

proc len*[T](archetypes: ArchetypeSet[T]): int = archetypes.archetypes.card

proc contains*[T](archetypes: ArchetypeSet[T], archetype: Archetype[T]): bool = archetype in archetypes.archetypes

iterator items*[T](archetypes: ArchetypeSet[T]): Archetype[T] =
    ## Produces all the archetypes
    for archetype in items(archetypes.archetypes):
        yield archetype

proc dumpAnalysis*[T](archetypes: ArchetypeSet[T]) =
    ## Prints an analysis of the archetypes in a set
    let allArchetypes = archetypes.toSeq
    for archetype in allArchetypes.sortedByIt(it.name):
        echo $archetype
    echo "TOTAL: ", allArchetypes.len