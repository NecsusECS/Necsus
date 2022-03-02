import openAddrIndex, sharedVector, options, threading/atomics, hashes

type
    Entry[K, V] = object
        key: K
        value: V
        visible: bool

    OpenAddrData*[K, V] = object
        used: Atomic[uint]
        dense: SharedVector[Entry[K, V]]
        sparse: SharedVector[AtomicDenseIdx]

    SetValueResult* = enum SetSuccess, ResizeNeeded, RetrySet

proc newOpenAddrData*[K, V](initialSize: uint): OpenAddrData[K, V] =
    ## Instantiates a new OpenAddrData
    result.dense = newSharedVector[Entry[K, V]](initialSize)
    result.sparse = newSharedVector[AtomicDenseIdx](initialSize)

proc capacity*[K, V](table: var OpenAddrData[K, V]): uint =
    ## Return the capacity of this data
    min(table.dense.len, table.sparse.len)

proc enlarge*[K, V](table: var OpenAddrData[K, V], newMinimumSize: uint) =
    ## Increases the key capacity of this table
    table.dense.reserve(newMinimumSize)
    table.sparse.reserve(newMinimumSize)

proc `$`*[K, V](table: var OpenAddrData[K, V]): string =
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

proc `=copy`*[K, V](dest: var OpenAddrData[K, V], src: OpenAddrData[K, V]) {.error.}

proc dump*[K, V](table: var OpenAddrData[K, V]): string =
    for i in 0'u..<table.sparse.len:
        let denseIdx = table.sparse.mget(i).load()
        if i > 0:
            result.add(", ")
        result.add($i & ": ")
        if denseIdx.isUnused:
            result.add("_")
        elif denseIdx.isTombstoned:
            result.add("X")
        else:
            let entry = table.dense[denseIdx.idx]
            if entry.visible:
                result.add("(" & $entry.key & ": " & $entry.value & ")")
            else:
                result.add("-")

proc bestIndex[K](key: K, tableSize: uint): uint =
    ## Returns the best index a key can be at for a given chunk
    result = key.hash.uint mod (tableSize - 1)

iterator indexes[K](startKey: K, tableCapacity: uint): uint =
    ## Iterates through the indexes for testing a key
    let start = bestIndex(startKey, tableCapacity)
    for i in start..<tableCapacity:
        yield i
    for i in 0'u..<start:
        yield i

template findStoreSlot[K, V](
    table: var OpenAddrData[K, V],
    key: K,
    tableCapacity: uint;
    sparseIdx, denseIdx, sparseEntry, denseEntry, onExisting, onNew: untyped
): untyped =
    ## Finds locations in the sparse index to store a key
    for sparseIdx in indexes(key, tableCapacity):
        let sparseEntry = addr mget(table.sparse, sparseIdx)
        var denseIdx = load(sparseEntry[])
        if isUsed(denseIdx):
            let denseEntry = addr mget(table.dense, idx(denseIdx))
            if denseEntry.key == key:
                onExisting
        elif isUnused(denseIdx):
            onNew

proc storeNew[K, V](
    table: var OpenAddrData[K, V],
    key: K,
    value: V,
    sparseEntry: ptr AtomicDenseIdx,
    existingDenseIdx: var DenseIdx
): (SetValueResult, ptr V) {.inline.} =

    let denseIdx = table.used.fetchAdd(1)

    let entry = addr table.dense.mget(denseIdx)
    entry.visible = false
    entry.value = value
    entry.key = key

    if compareExchange(sparseEntry[], existingDenseIdx, denseIdx.asDenseIdx):
        entry.visible = true
        return (SetSuccess, addr entry.value)
    else:
        ## TODO: When this fails, it leaves the dense entry we created stranded
        return (RetrySet, nil)

proc write*[K, V](
    table: var OpenAddrData[K, V],
    key: K,
    value: sink V,
    tableCapacity: uint
): (SetValueResult, ptr V) =
    ## Attempts to set a value, returning a code representing the result of that operation

    findStoreSlot(table, key, tableCapacity, sparseIdx, denseIdx, sparseEntry, denseEntry):
        denseEntry.value = value
        return (SetSuccess, addr denseEntry.value)
    do:
        return storeNew(table, key, value, sparseEntry, denseIdx)

    return (ResizeNeeded, nil)

proc cleanup*[K, V](table: var OpenAddrData[K, V]) =
    ## Removes any unnecessary tombstoned values
    var tombstonedRun = 0'u
    for i in 0'u..<table.sparse.len:
        let denseIdx = table.sparse.mget(i).load
        if denseIdx.isTombstoned:
            tombstonedRun += 1
        elif denseIdx.isUnused:
            block done:
                var tombstoned = Tombstoned
                for cleanup in 1'u..<tombstonedRun:
                    if not table.sparse.mget(i - cleanup).compareExchange(tombstoned, Unused):
                        break done
        else:
            tombstonedRun = 0

proc migrate*[K, V](table: var OpenAddrData[K, V], oldCapacity, newCapacity: uint) =
    ## Moves keys from the old capacity to the new capacity
    for toMigrate in 0'u..<oldCapacity:
        block next:
            let denseIdx = table.sparse.mget(toMigrate).load()
            if denseIdx.isUsed:
                let key = table.dense[denseIdx.idx].key
                findStoreSlot(table, key, newCapacity, sparseIdx, existingDenseIdx, sparseEntry, denseEntry):
                    # If we hit this branch, it means the key already exists at a findable location
                    break next
                do:
                    if table.sparse.mget(sparseIdx).compareExchange(existingDenseIdx, denseIdx):
                        table.sparse.mget(toMigrate).store(Tombstoned)
                        break next
                assert(false, "Migration of key failed! " & $key)

iterator capacities[K](key: K, capacity1, capacity2: var Atomic[uint]): uint =
    ## When a table gets resized, the key may still exist at the old location. So we check the new size,
    ## and the old size, then back to the new size again to see if it was moved

    let cap1 = capacity1.load
    yield cap1

    let cap2 = capacity2.load
    if cap2 != cap1:
        yield cap2

    let cap3 = capacity1.load
    if cap3 != cap2 or cap3 != cap1:
        yield cap2

template find[K, V](
    table: var OpenAddrData[K, V],
    key: K,
    capacity1, capacity2: var Atomic[uint],
    denseIdx, sparseIdx, whenFound: untyped
): untyped =
    ## Searches for the given key and executes a block of code when it is found
    for capacity in capacities(key, capacity1, capacity2):
        for sparseIdx in indexes(key, capacity):
            var denseIdx = load(mget(table.sparse, sparseIdx))

            if isUsed(denseIdx) and table.dense[idx(denseIdx)].key == key:
                whenFound
            elif isUnused(denseIdx):
                break

proc read*[K, V](table: var OpenAddrData[K, V], key: K, capacity1, capacity2: var Atomic[uint]): var V =
    ## Reads a key from this table
    find(table, key, capacity1, capacity2, denseIdx, sparseIdx):
        return table.dense.mget(denseIdx.idx).value
    when compileOption("boundChecks"):
        raise newException(KeyError, "Key does not exist: " & $key)

proc maybeRead*[K, V](table: var OpenAddrData[K, V], key: K, capacity1, capacity2: var Atomic[uint]): Option[V] =
    ## Reads a key from this table
    find(table, key, capacity1, capacity2, denseIdx, sparseIdx):
        return some(table.dense[denseIdx.idx].value)
    return none(V)

proc maybeReadPointer*[K, V](
    table: var OpenAddrData[K, V],
    key: K,
    capacity1, capacity2: var Atomic[uint]
): Option[ptr V] =
    ## Reads a key from this table
    find(table, key, capacity1, capacity2, denseIdx, sparseIdx):
        return some(addr table.dense.mget(denseIdx.idx).value)
    return none(ptr V)

proc contains*[K, V](table: var OpenAddrData[K, V], key: K, capacity1, capacity2: var Atomic[uint]): bool =
    ## Determines whether a key is in this table
    find(table, key, capacity1, capacity2, denseIdx, sparseIdx):
        return true
    return false

proc del*[K, V](table: var OpenAddrData[K, V], key: K, capacity1, capacity2: var Atomic[uint]) =
    ## Tombstones a key in this table
    find(table, key, capacity1, capacity2, denseIdx, sparseIdx):
        table.sparse.mget(sparseIdx).store(Tombstoned)
        table.dense[denseIdx.idx] = Entry[K, V](visible: false)
        # TODO: Recycle the dense index

iterator items*[K, V](table: var OpenAddrData[K, V]): lent V =
    ## Iterate over the values in this table
    for i in 0'u..table.used.load:
        let entry = addr table.dense.mget(i)
        if entry.visible:
            yield entry.value

iterator pairs*[K, V](table: var OpenAddrData[K, V]): (K, V) =
    ## Iterate over the keys and values in this table
    for i in 0'u..table.used.load:
        let entry = addr table.dense.mget(i)
        if entry.visible:
            yield (entry.key, entry.value)
