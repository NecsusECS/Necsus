import atomics, math, sequtils, strutils, openAddrTable, strformat

type
    Entry*[T] = tuple[key: int32, value: T]

    PackedIntTableValue*[T] = object
        ## A direct pointer to an entry
        entry: ptr Entry[T]
        expectKey: int32

    PackedIntTable*[T] {.byref.} = object
        ## A packed tabled where the key is always an int
        keyMap: OpenAddrTable[int32, int32]
        entries: seq[Entry[T]]
        maxIndex: int32

proc newPackedIntTable*[T](initialSize: int): PackedIntTable[T] =
    ## Create a new PackedIntTable
    result = PackedIntTable[T](
        keyMap: newOpenAddrTable[int32, int32](initialSize),
        entries: newSeq[Entry[T]](initialSize)
    )

proc `=copy`*[T](dest: var PackedIntTable[T], src: PackedIntTable[T]) {.error.}

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
        result.add($key & ": " & $value)
    result.add "}"

proc `[]`*[T](table: var PackedIntTable[T], key: int32): var T =
    ## Fetch a value
    return table.entries[table.keyMap[key]].value

proc setValue[T](table: var PackedIntTable[T], key: int32, value: sink T): int32 {.inline.} =
    ## Sets a value in the table and returns the generated index
    if key in table.keyMap:
        result = table.keyMap[key]
    else:
        result = table.maxIndex
        table.maxIndex += 1
        if result >= table.entries.len:
            table.entries.setLen(ceilDiv(result * 3, 2))
        table.keyMap[key] = result
    table.entries[result] = (key, value)

proc `[]=`*[T](table: var PackedIntTable[T], key: int32, value: sink T) =
    ## Add a value
    discard table.setValue(key, value)

proc setAndRef*[T](table: var PackedIntTable[T], key: int32, value: sink T): PackedIntTableValue[T] =
    ## Add a value and return a value reference to it
    PackedIntTableValue[T](entry: addr table.entries[table.setValue(key, value)], expectKey: key)

proc getRef*[T](table: var PackedIntTable[T], key: int32): PackedIntTableValue[T] =
    ## Returns a ref to a key
    PackedIntTableValue[T](entry: addr table.entries[table.keyMap[key]], expectKey: key)

proc contains*[T](table: var PackedIntTable[T], key: int32): bool =
    ## Determine whether a key exists in this table
    key in table.keyMap

proc del*[T](table: var PackedIntTable[T], key: int32) =
    ## Removes a key from this table
    let idx = table.keyMap[key]
    table.keyMap.del(key)
    table.maxIndex -= 1

    ## To keep the table packed, move the last element into the deleted slot
    if table.maxIndex > 0 and table.maxIndex != idx:

        let toCopy = table.entries[table.maxIndex]
        table.entries[idx] = toCopy
        table.keyMap[toCopy.key] = idx

        # Change the key of the moved value so that lookups will fail
        table.entries[table.maxIndex].key += 1

proc reference*[T](table: var PackedIntTable[T], key: int32): PackedIntTableValue[T] =
    ## Returns a direct reference to an entry in the table
    PackedIntTableValue[T](entry: unsafeAddr table.entries[table.keyMap[key]], expectKey: key)

proc `[]`*[T](table: var PackedIntTable[T], reference: PackedIntTableValue[T]): lent T =
    ## Fetch a value
    if reference.entry.key == reference.expectKey:
        result = reference.entry.value
    else:
        result = table[reference.expectKey]

proc getPointer*[T](table: var PackedIntTable[T], reference: PackedIntTableValue[T]): ptr T =
    ## Returns a pointer to the given value instead of the value itself. Allows for in place updates
    if reference.entry.key == reference.expectKey:
        result = addr reference.entry.value
    else:
        result = unsafeAddr table.entries[table.keyMap[reference.expectKey]].value
