import sets, tables, sequtils, algorithm, hashes, strutils

##
## A system for grouping together values into non-overlapping groups. This
## is used to figure out which values can be stored together based on
## how they are created
##

# To resolve https://github.com/nim-lang/Nim/issues/11167
export sets.items

type
    Group*[T] = ref object
        ## A group of values that can be stored together
        values: seq[T]
        indexes: Table[T, int]

    GroupTable*[T] = object
        ## Maps values to the group they belong to
        groups: HashSet[Group[T]]
        lookup: Table[T, Group[T]]

    Grouper*[T] = object
        ## Tracks state while calculating groups
        groups: HashSet[HashSet[T]]

proc newGrouper*[T](): Grouper[T] =
    ## Creates a new Grouper instance
    result.groups = initHashSet[HashSet[T]]()

proc add*[T](builder: var Grouper[T], group: openarray[T]) =
    ## Adds a new group of values

    var remainingAdditions = toHashSet(group)
    var newGroups = initHashSet[HashSet[T]]()

    for existing in builder.groups:
        let difference = existing - remainingAdditions
        if difference.len > 0: newGroups.incl(difference)

        let intersection = intersection(existing, remainingAdditions)
        if intersection.len > 0: newGroups.incl(intersection)

        remainingAdditions = remainingAdditions - existing

    if remainingAdditions.len > 0:
        newGroups.incl(remainingAdditions)

    builder.groups = newGroups

proc newGroup[T](values: HashSet[T]): Group[T] =
    ## Create a new group
    result.new
    result.values = values.toSeq
    result.values.sort
    result.indexes = initTable[T, int](result.values.len)
    for i, value in result.values:
        result.indexes[value] = i

iterator items*[T](group: Group[T]): T =
    ## Produces all the values in a group, in sorted order
    for value in group.values: yield value

proc hash*[T](group: Group[T]): Hash =
    ## Create a hash describing a group
    for value in group:
        result = result !& hash(value)

proc `==`*[T](a, b: Group[T]): bool =
    ## Determine group equality
    a.values == b.values

proc `$`*[T](group: Group[T]): string =
    ## Stringify a group
    result.add("{")
    result.add(group.toSeq.join(", "))
    result.add("}")

proc `[]`*[T](group: Group[T], value: T): int =
    ## Returns the index of a value in a group
    group.indexes[value]

proc build*[T](builder: Grouper[T]): GroupTable[T] =
    ## Creates the final table of groups
    result.groups = initHashSet[Group[T]]()
    result.lookup = initTable[T, Group[T]]()
    for rawGroup in builder.groups:
        let group = newGroup(rawGroup)
        result.groups.incl(group)
        for value in group:
            result.lookup[value] = group

proc contains*[T](groupTable: GroupTable[T], value: T): bool =
    ## Whether a value is in a group
    value in groupTable.lookup

proc `[]`*[T](groupTable: GroupTable[T], value: T): Group[T] =
    ## Returns the group for a value
    groupTable.lookup[value]

iterator items*[T](groupTable: GroupTable[T]): Group[T] =
    ## Produces all the groups
    for group in groupTable.groups: yield group

proc `$`*[T](groupTable: GroupTable[T]): string =
    "GroupTable(" & groupTable.groups.mapIt($it).join(", ") & ")"
