import tables

proc nameTable*[T](
    values: openarray[T],
    baseName: proc(value: T): string
): OrderedTable[T, string] =
    ## Creates a table of unique names for each unique value
    result = initOrderedTable[T, string]()
    var suffixes = initTable[string, int]()
    for elem in values.toSeq.deduplicate:
        let name = baseName(elem)
        let suffix = suffixes.mgetOrPut(name, 0)
        suffixes[name] = suffix + 1
        result[elem] = name & $suffix

