import denseIdxs, options, threading/atomics, hashes

type
    Entry[K, V] = object
        key: K
        value: V
        visible: bool

    FixedSizeTable*[K, V] = object
        capacity: uint
        used: Atomic[uint]
        dense: ptr UncheckedArray[Entry[K, V]]
        sparse: ptr UncheckedArray[AtomicDenseIdx]

proc allocateArray(typ: typedesc, len: SomeInteger): ptr UncheckedArray[typ] =
    let memsize = uint(sizeof(typ)) * len.uint
    let mem = allocShared(memsize)
    mem.zeroMem(memsize)
    result = cast[ptr UncheckedArray[typ]](mem)

proc newFixedSizeTable*[K, V](size: SomeInteger): FixedSizeTable[K, V] =
    ## Instantiates a new FixedSizeTable
    result.capacity = size.uint
    result.dense = allocateArray(Entry[K, V], size)
    result.sparse = allocateArray(AtomicDenseIdx, size)

proc `$`*[K, V](table: var FixedSizeTable[K, V]): string =
    result.add("{")
    var first = true
    for i in 0'u..<table.used.load:
        let entry = table.dense[i]
        if entry.visible:
            if first:
                first = false
            else:
                result.add(", ")
            result.add($entry.key)
            result.add(": ")
            result.add($entry.value)
    result.add("}")

proc `=copy`*[K, V](dest: var FixedSizeTable[K, V], src: FixedSizeTable[K, V]) {.error.}

proc bestIndex[K](key: K, tableSize: uint): uint =
    ## Returns the best index a key can be at for a given chunk
    result = key.hash.uint mod (tableSize - 1)

iterator indexes[K](startKey: K, tableSize: uint): uint =
    ## Iterates through the indexes for testing a key
    let start = bestIndex(startKey, tableSize)
    for i in start..<tableSize:
        yield i
    for i in 0'u..<start:
        yield i

template findStoreSlot[K, V](
    table: var FixedSizeTable[K, V],
    key: K,
    sparseIdx, denseIdx, sparseEntry, denseEntry, onExisting, onNew: untyped
): untyped =
    ## Finds locations in the sparse index to store a key
    for sparseIdx in indexes(key, table.capacity):
        let sparseEntry = addr table.sparse[sparseIdx]
        var denseIdx = load(sparseEntry[])
        if isUsed(denseIdx):
            let denseEntry = addr table.dense[idx(denseIdx)]
            if denseEntry.key == key:
                onExisting
        elif isUnused(denseIdx):
            onNew

proc storeNew[K, V](
    table: var FixedSizeTable[K, V],
    key: K,
    value: V,
    sparseEntry: ptr AtomicDenseIdx,
    existingDenseIdx: var DenseIdx
): ptr V {.inline.} =

    let denseIdx = table.used.fetchAdd(1)

    let entry = addr table.dense[denseIdx]
    entry.visible = false
    entry.value = value
    entry.key = key

    if compareExchange(sparseEntry[], existingDenseIdx, denseIdx.asDenseIdx):
        entry.visible = true
        return addr entry.value
    else:
        ## TODO: When this fails, it leaves the dense entry we created stranded
        return nil

proc setAndRef*[K, V](table: var FixedSizeTable[K, V], key: K, value: sink V): ptr V =
    ## Attempts to set a value, returning a code representing the result of that operation

    findStoreSlot(table, key, sparseIdx, denseIdx, sparseEntry, denseEntry):
        denseEntry.value = value
        return addr denseEntry.value
    do:
        return storeNew(table, key, value, sparseEntry, denseIdx)

    return nil

proc `[]=`*[K, V](table: var FixedSizeTable[K, V], key: K, value: sink V) =
    let reference = setAndRef(table, key, value)
    when compileOption("boundChecks"):
        if reference == nil:
            raise newException(KeyError, "Could not set key: " & $key)

template find[K, V](
    table: var FixedSizeTable[K, V],
    key: K,
    denseIdx, sparseIdx, whenFound: untyped
): untyped =
    ## Searches for the given key and executes a block of code when it is found
    for sparseIdx in indexes(key, table.capacity):
        var denseIdx = load(table.sparse[sparseIdx])

        if isUsed(denseIdx) and table.dense[idx(denseIdx)].key == key:
            whenFound
        elif isUnused(denseIdx):
            break

proc `[]`*[K, V](table: var FixedSizeTable[K, V], key: K): var V =
    ## Reads a key from this table
    find(table, key, denseIdx, sparseIdx):
        return table.dense[denseIdx.idx].value
    when compileOption("boundChecks"):
        raise newException(KeyError, "Key does not exist: " & $key)

proc maybeGet*[K, V](table: var FixedSizeTable[K, V], key: K): Option[V] =
    ## Reads a key from this table
    find(table, key, denseIdx, sparseIdx):
        return some(table.dense[denseIdx.idx].value)
    return none(V)

proc maybeGetPointer*[K, V](table: var FixedSizeTable[K, V], key: K): Option[ptr V] =
    ## Reads a key from this table
    find(table, key, denseIdx, sparseIdx):
        return some(addr table.dense[denseIdx.idx].value)
    return none(ptr V)

proc contains*[K, V](table: var FixedSizeTable[K, V], key: K): bool =
    ## Determines whether a key is in this table
    find(table, key, denseIdx, sparseIdx):
        return true
    return false

proc del*[K, V](table: var FixedSizeTable[K, V], key: K) =
    ## Tombstones a key in this table
    find(table, key, denseIdx, sparseIdx):
        table.sparse[sparseIdx].store(Tombstoned)
        table.dense[denseIdx.idx] = Entry[K, V](visible: false)
        # TODO: Recycle the dense index

iterator items*[K, V](table: var FixedSizeTable[K, V]): lent V =
    ## Iterate over the values in this table
    for i in 0'u..table.used.load:
        let entry = addr table.dense[i]
        if entry.visible:
            yield entry.value

iterator pairs*[K, V](table: var FixedSizeTable[K, V]): (K, V) =
    ## Iterate over the keys and values in this table
    for i in 0'u..table.used.load:
        let entry = addr table.dense[i]
        if entry.visible:
            yield (entry.key, entry.value)
