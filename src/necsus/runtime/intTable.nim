import tables, atomics, math, sequtils, strutils

type
    Entry*[T] = tuple[key: int, value: T]

    IntTableValue*[T] = object
        ## A direct pointer to an entry
        entry: ptr Entry[T]
        expectKey: int

    IntTable*[T] {.byref.} = object
        ## A packed tabled where the key is always an int
        keyMap: Table[int, int]
        entries: seq[Entry[T]]
        maxIndex: int

proc newIntTable*[T](initialSize: int): IntTable[T] =
    ## Create a new IntTable
    result = IntTable[T](
        keyMap: initTable[int, int](initialSize),
        entries: newSeq[Entry[T]](initialSize)
    )

proc `[]`*[T](table: IntTable[T], key: int): lent T =
    ## Fetch a value
    table.entries[table.keyMap[key]].value

proc `[]=`*[T](table: var IntTable[T], key: int, value: sink T) =
    ## Add a value
    let nextIndex = table.maxIndex
    table.maxIndex += 1
    if nextIndex >= table.entries.len:
        table.entries.setLen(ceilDiv(nextIndex * 3, 2))
    table.entries[nextIndex] = (key, value)
    table.keyMap[key] = nextIndex

proc contains*[T](table: IntTable[T], key: int): bool =
    ## Determine whether a key exists in this table
    key in table.keyMap

iterator items*[T](table: IntTable[T]): lent T =
    ## Iterate through all values
    for i in 0..<table.maxIndex:
        yield table.entries[i].value

iterator pairs*[T](table: IntTable[T]): lent Entry[T] =
    ## Iterate through all values
    for i in 0..<table.maxIndex:
        yield table.entries[i]

proc `$`*[T](table: IntTable[T]): string =
    ## Debug string generation
    result = "{"
    var first = true
    for (key, value) in table.pairs:
        if first: first = false else: result.add ", "
        result.add $key
        result.add ": "
        result.add $value
    result.add "}"

proc del*[T](table: var IntTable[T], key: int) =
    ## Removes a key from this table
    let idx = table.keyMap[key]
    table.keyMap.del(key)
    table.maxIndex -= 1

    ## To keep the table packed, move the last element into the deleted slot
    if table.maxIndex > 0:

        let toCopy = table.entries[table.maxIndex]
        table.entries[idx] = toCopy
        table.keyMap[toCopy.key] = idx

        # Change the key of the moved value so that lookups will fail
        table.entries[table.maxIndex].key += 1

proc reference*[T](table: IntTable[T], key: int): IntTableValue[T] =
    ## Returns a direct reference to an entry in the table
    IntTableValue[T](entry: unsafeAddr table.entries[table.keyMap[key]], expectKey: key)

proc `[]`*[T](table: IntTable[T], reference: IntTableValue[T]): lent T =
    ## Fetch a value
    if reference.entry.key == reference.expectKey:
        result = reference.entry.value
    else:
        result = table[reference.expectKey]

