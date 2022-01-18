import tables, atomics, math, sequtils, strutils

type
    Entry*[T] = tuple[key: int, value: T]

    PackedIntTableValue*[T] = object
        ## A direct pointer to an entry
        entry: ptr Entry[T]
        expectKey: int

    PackedIntTable*[T] {.byref.} = object
        ## A packed tabled where the key is always an int
        keyMap: Table[int, int]
        entries: seq[Entry[T]]
        maxIndex: int

proc newPackedIntTable*[T](initialSize: int): PackedIntTable[T] =
    ## Create a new PackedIntTable
    result = PackedIntTable[T](
        keyMap: initTable[int, int](initialSize),
        entries: newSeq[Entry[T]](initialSize)
    )

proc `[]`*[T](table: PackedIntTable[T], key: int): lent T =
    ## Fetch a value
    table.entries[table.keyMap[key]].value

proc setValue[T](table: var PackedIntTable[T], key: int, value: sink T): int {.inline.} =
    ## Sets a value in the table and returns the generated index
    result = table.maxIndex
    table.maxIndex += 1
    if result >= table.entries.len:
        table.entries.setLen(ceilDiv(result * 3, 2))
    table.entries[result] = (key, value)
    table.keyMap[key] = result

proc `[]=`*[T](table: var PackedIntTable[T], key: int, value: sink T) =
    ## Add a value
    discard table.setValue(key, value)

proc setAndRef*[T](table: var PackedIntTable[T], key: int, value: sink T): PackedIntTableValue[T] =
    ## Add a value and return a value reference to it
    PackedIntTableValue[T](entry: addr table.entries[table.setValue(key, value)], expectKey: key)

proc contains*[T](table: PackedIntTable[T], key: int): bool =
    ## Determine whether a key exists in this table
    key in table.keyMap

iterator items*[T](table: PackedIntTable[T]): lent T =
    ## Iterate through all values
    for i in 0..<table.maxIndex:
        yield table.entries[i].value

iterator pairs*[T](table: PackedIntTable[T]): lent Entry[T] =
    ## Iterate through all values
    for i in 0..<table.maxIndex:
        yield table.entries[i]

proc `$`*[T](table: PackedIntTable[T]): string =
    ## Debug string generation
    result = "{"
    var first = true
    for (key, value) in table.pairs:
        if first: first = false else: result.add ", "
        result.add $key
        result.add ": "
        result.add $value
    result.add "}"

proc del*[T](table: var PackedIntTable[T], key: int) =
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

proc reference*[T](table: PackedIntTable[T], key: int): PackedIntTableValue[T] =
    ## Returns a direct reference to an entry in the table
    PackedIntTableValue[T](entry: unsafeAddr table.entries[table.keyMap[key]], expectKey: key)

proc `[]`*[T](table: PackedIntTable[T], reference: PackedIntTableValue[T]): lent T =
    ## Fetch a value
    if reference.entry.key == reference.expectKey:
        result = reference.entry.value
    else:
        result = table[reference.expectKey]

