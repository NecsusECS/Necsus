import openAddrTable, blockStorage, packedList, options

#
# PackedIntTable
#

type
    Entry*[T] = tuple[key: int32, value: T]

    PackedIntTableValue*[T] = object
        ## A direct pointer to an entry
        entry: ptr Entry[T]
        expectKey: int32

    PackedIntTable*[T] {.byref.} = object
        ## A packed tabled where the key is always an int
        keyMap: OpenAddrTable[int32, int32]
        entries: PackedList[Entry[T]]

proc newPackedIntTable*[T](initialSize: int): PackedIntTable[T] =
    ## Create a new PackedIntTable
    result.keyMap = newOpenAddrTable[int32, int32](initialSize)
    result.entries = newPackedList[Entry[T]](initialSize)

proc `=copy`*[T](dest: var PackedIntTable[T], src: PackedIntTable[T]) {.error.}

iterator items*[T](table: var PackedIntTable[T]): lent T =
    ## Iterate through all values
    for entry in items(table.entries):
        yield entry.value

iterator pairs*[T](table: var PackedIntTable[T]): Entry[T] =
    ## Iterate through all values
    for entry in items(table.entries):
        yield entry

proc `$`*[T](table: var PackedIntTable[T]): string =
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

proc getPointer*[T](table: var PackedIntTable[T], key: int32): ptr T =
    ## Fetch a value as a pointer
    return addr table.entries[table.keyMap[key]].value

proc maybeGet*[T](table: var PackedIntTable[T], key: int32): Option[T] =
    ## Fetch a value if it exists
    let index = table.keyMap.maybeGet(key)
    return if index.isSome: return some(table.entries[index.get()].value) else: none(T)

proc maybeGetPointer*[T](table: var PackedIntTable[T], key: int32): Option[ptr T] =
    ## Fetch a pointer to a value if it exists
    let index = table.keyMap.maybeGet(key)
    return if index.isSome: return some(addr table.entries[index.get()].value) else: none(ptr T)

proc setValue[T](table: var PackedIntTable[T], key: int32, value: sink T): int32 {.inline.} =
    ## Sets a value in the table and returns the generated index
    if key in table.keyMap:
        result = table.keyMap[key]
        table.entries[result] = (key, value)
    else:
        result = table.entries.push((key, value)).int32
        table.keyMap[key] = result

proc `[]=`*[T](table: var PackedIntTable[T], key: int32, value: sink T) =
    ## Add a value
    discard table.setValue(key, value)

proc setAndRef*[T](table: var PackedIntTable[T], key: int32, value: sink T): PackedIntTableValue[T] =
    ## Add a value and return a value reference to it
    result.entry = addr table.entries[table.setValue(key, value)]
    result.expectKey = key

proc getRef*[T](table: var PackedIntTable[T], key: int32): PackedIntTableValue[T] =
    ## Returns a ref to a key
    PackedIntTableValue[T](entry: addr table.entries[table.keyMap[key]], expectKey: key)

proc contains*[T](table: var PackedIntTable[T], key: int32): bool =
    ## Determine whether a key exists in this table
    key in table.keyMap

proc del*[T](table: var PackedIntTable[T], key: int32) =
    ## Removes a key from this table
    let idx = table.keyMap.maybeGet(key)
    if idx.isSome:
        table.keyMap.del(key)

        table.entries.deleteKey(idx.get, moved):
            table.keyMap[moved.key] = idx.get
            moved.key += 1

proc reference*[T](table: var PackedIntTable[T], key: int32): PackedIntTableValue[T] =
    ## Returns a direct reference to an entry in the table
    PackedIntTableValue[T](entry: addr table.entries[table.keyMap[key]], expectKey: key)

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
        result = addr table.entries[table.keyMap[reference.expectKey]].value
