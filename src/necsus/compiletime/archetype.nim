import std/[tables, sets, hashes, strutils, sequtils, macros, algorithm, macrocache, strformat, options]
import componentDef, ../util/[bits, typeReader], ../runtime/[world, pragmas], directiveArg, tupleDirective

type
    Archetype*[T] = ref object
        ## A archetype of values that can be stored together
        values: seq[T]
        name*: string
        identName: string
        allComps: Bits
        accessoryComps: Bits
        id: ArchetypeId

    ArchetypeSet*[T] = ref object
        ## A set of all known archetypes
        accessories: Bits
        archetypes: Table[Bits, Archetype[T]]

    UnsortedArchetype* = object of Defect
        ## Thrown when an archetype is out of sorted order

proc generateName(values: openarray[string]): string = values.join("_")

when NimMajor >= 2:
    const nextId = CacheCounter("NextArchetypeId")
    const ids = CacheTable("ArchetypeIds")
else:
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

proc newArchetype*[T](values: openarray[T], accessories: Bits): Archetype[T] =
    ## Create an archetype

    var accessoryComps = Bits()
    var allComps = Bits()

    var verified: seq[T]
    var previous: T
    for i, value in values:
        if i > 0 and value < previous:
            let correct = values.sorted().join(", ")
            raise newException(UnsortedArchetype, "Archetype must be in sorted order. Correct order is: " & correct)
        elif i == 0 or previous != value:
            verified.add(value)
            allComps.incl(value.uniqueId)

            if value.uniqueId in accessories:
                accessoryComps.incl(value.uniqueId)
        previous = value

    let name = generateName(verified)

    return Archetype[T](
        values: verified,
        name: name,
        identName: "archetype_" & name,
        allComps: allComps,
        accessoryComps: accessoryComps,
        id: name.getId,
    )

proc hasAccessories*(arch: Archetype): bool =
    ## Returns whether there are any accessories in this archetype
    return arch.accessoryComps.card > 0

proc isAccessory*[T](arch: Archetype[T], value: T): bool = value.uniqueId in arch.accessoryComps
    ## Whether a specific value is an accessory

proc readableName*(arch: Archetype[ComponentDef]): string = arch.values.mapIt(it.readableName).join("_")
    ## Returns a readable name that describes an archetype

proc hash*[T](archetype: Archetype[T]): Hash = archetype.allComps.hash
    ## Create a hash describing a archetype

proc `==`*[T](a, b: Archetype[T]): bool =
    ## Determine archetype equality
    a.allComps == b.allComps

proc `$`*[T](archetype: Archetype[T]): string =
    ## Stringify a Archetype
    result.add("{")
    var first = true
    for comp in archetype.values:
        if first:
            first = false
        else:
            result.add(", ")
        result.add($comp)
        if comp.uniqueId in archetype.accessoryComps:
            result.add("?")
    result.add("}")

proc contains*[T](archetype: Archetype[T], value: T): bool =
    ## Whether an archetype contains all the given value
    value.uniqueId in archetype.allComps

proc indexOf*[T](archetype: Archetype[T], value: T): int =
    ## Whether an archetype contains all the given value
    result = archetype.values.binarySearch(value)
    assert(result != -1, $value & " is not in archetype " & $archetype)

proc containsAllOf*[T](archetype: Archetype[T], others: openarray[T]): bool =
    ## Whether an archetype contains all the given values
    for other in others:
        if other notin archetype:
            return false
    return true

proc removeAndAdd*[T](archetype: Archetype[T], remove: Bits, add: openarray[T]): seq[T] =
    for value in archetype:
        if value.uniqueId notin remove:
            result.add(value)
    if add.len > 0:
        for value in add:
            if value notin archetype:
                result.add(value)
        result.sort()

proc ident*(archetype: Archetype[ComponentDef]): NimNode = archetype.identName.ident
    ## Creates a variable for referencing an archetype store

proc asStorageTuple*(archetype: Archetype[ComponentDef]): NimNode =
    ## Creates the tuple type for storing an archetype
    result = nnkTupleConstr.newTree()
    for component in archetype.values:
        if component.isAccessory:
            result.add(nnkBracketExpr.newTree(bindSym("Option"), component.ident))
        else:
            result.add(component.ident)

iterator items*[T](archetype: Archetype[T]): T =
    ## Produces all the archetype values
    for value in archetype.values: yield value

proc values*[T](archetype: Archetype[T]): seq[T] = archetype.values
    ## Produces all the archetype values

when NimMajor >= 2:
    const archetypeSymbols = CacheTable("NecsusArchetypeIdSymbols")
else:
    var archetypeSymbols {.compileTime.} = initTable[string, NimNode]()

const idSymCounter = CacheCounter("NecsusArchetypeIdSymbols")

proc idSymbol*[T](archetype: Archetype[T]): NimNode =
    ## Returns a unique symbol containing an ID for this archetype
    if archetype.name notin archetypeSymbols:
        archetypeSymbols[archetype.name] = genSym(nskConst, "archetypeId" & idSymCounter.value.toHex(4))
        idSymCounter.inc
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
        {.hint[ConvFromXtoItselfNotNeeded]:off.}
        const `symbol` = ArchetypeId(`num`)

proc newArchetypeSet*[T](values: openarray[Archetype[T]], accessories: Bits): ArchetypeSet[T] =
    ## Creates a set of archetypes
    result = ArchetypeSet[T](archetypes: initTable[Bits, Archetype[T]](values.len), accessories: accessories)
    for arch in values:
        let key = arch.allComps - accessories
        assert(key notin result.archetypes)
        result.archetypes[key] = arch

proc len*[T](archetypes: ArchetypeSet[T]): int = archetypes.archetypes.len

proc contains*[T](archetypes: ArchetypeSet[T], archetype: Archetype[T]): bool = archetype in archetypes.archetypes

iterator items*[T](archetypes: ArchetypeSet[T]): Archetype[T] =
    ## Produces all the archetypes
    for _, archetype in pairs(archetypes.archetypes):
        yield archetype

proc dumpAnalysis*[T](archetypes: ArchetypeSet[T]) =
    ## Prints an analysis of the archetypes in a set
    let allArchetypes = archetypes.toSeq
    for archetype in allArchetypes.sortedByIt(it.name):
        echo $archetype
    echo "TOTAL: ", allArchetypes.len

proc archetypeFor*[T](archs: ArchetypeSet[T], components: openArray[T]): Archetype[T] =
    ## Returns the archetype to use for a set of components
    var bits = Bits()
    for comp in components:
        if not comp.isAccessory:
            bits.incl(comp.uniqueId)
    if bits in archs.archetypes:
        return archs.archetypes[bits]

proc matches*(arch: Archetype, filter: BitsFilter): bool =
    ## Whether this archetype can fulfill the given filter
    filter.matches(all = arch.allComps, optional = arch.accessoryComps)

proc asTupleDir*(arch: Archetype[ComponentDef]): TupleDirective =
    ## Convert an archetype to a TupleDirective
    var args = newSeq[DirectiveArg](arch.values.len)
    for i, comp in arch.values:
        args[i] = newDirectiveArg(comp, false, if comp.isAccessory: Optional else: Include)
    return newTupleDir(args)

when NimMajor >= 2:
    const capacityCache = CacheTable("NecsusCapacityCache")
else:
    var capacityCache {.compileTime.} = initTable[string, NimNode]()

proc getCapacity(node: NimNode): Option[NimNode] =
    case node.kind
    of nnkSym:
        let hash = node.signatureHash
        if hash in capacityCache:
            let cached = capacityCache[hash]
            return if cached.kind == nnkEmpty: none(NimNode) else: some(cached)

        var res = node.getImpl.getCapacity()
        if res.isNone:
            let dealiased = node.resolveAlias()
            if dealiased.isSome:
                res = dealiased.get.getCapacity()

        capacityCache[hash] = if res.isSome: res.get else: newEmptyNode()

        return res
    of nnkObjectTy, nnkTypeDef:
        for pragma in node.findPragma:
            if pragma.isPragma(bindSym("maxCapacity")):
                return some(pragma[1])
    of nnkBracketExpr:
        return node[0].getCapacity
    else:
        return none(NimNode)


proc calculateSize*(arch: Archetype[ComponentDef]): Option[NimNode] =
    ## Calculates the storage size required to store the components of an archetype
    for comp in arch:
        let capacity = comp.node.getCapacity
        if capacity.isSome:
            let newValue = newCall("uint", capacity.get)
            if result.isSome:
                result = some(newCall(bindSym("max"), result.get, newValue))
            else:
                result = some(newValue)

    when defined(requireMaxCapacity):
        if result.isNone:
            for comp in arch:
                hint(fmt"{comp} does not have a maxCapacity pragma", comp.node)
            error(fmt"Archetype must have at least one component with a maxCapacity defined: {arch}")

