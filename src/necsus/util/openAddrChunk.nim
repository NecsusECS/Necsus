import openAddrEntry, threading/atomics, options, math

##
## Chunk
##

type
    ExistingKeyMode* = enum
        ## A flag for how to handle existing keys
        SkipOnExisting, OverwriteExisting, RaiseOnExisting

    Chunk*[K, V] = object
        ## A block of values in the map
        size*: int
        consumedCapacity*: Atomic[int]
        activeReaders*: Atomic[int]
        activeWriters*: Atomic[int]
        oldChunk*: Atomic[ptr Chunk[K, V]]
        entries: UncheckedArray[Atomic[int64]]

proc newChunk*[K: SmallValue, V: SmallValue](minSize: int): ptr Chunk[K, V] =
    let size = max(minSize.nextPowerOfTwo, 64)
    let memSize  = sizeof(Chunk[K, V]) + (sizeof(Entry[K, V]) * size)
    result = cast[ptr Chunk[K, V]](allocShared(memSize))
    result.zeroMem(memSize)
    result.size = size

proc `=copy`*[K, V](dest: var Chunk[K, V], src: Chunk[K, V]) {.error.}

iterator items*[K, V](chunk: ptr Chunk[K, V]): Entry[K, V] =
    ## Iterate through all used keys and values in a chunk
    for i in 0..<chunk.size:
        let item = Entry[K, V](chunk.entries[i])
        if item.isState(UsedKey):
            yield item

proc `$`*[K, V](chunk: ptr Chunk[K, V]): string =
    ## Stringifies a chunk
    var isFirst = true
    for item in chunk.items:
        if isFirst: isFirst = false else: result.add(", ")
        result.add($item)

proc bestIndex[K, V](chunk: ptr Chunk[K, V], key: K): uint64 =
    ## Returns the best index a key can be at for a given chunk
    # Yes, this is a ridiculous hashing function. But it's also ridiculously fast
    (key.uint64 * 7) mod (chunk.size - 1).uint64

proc dump*[K, V](chunk: ptr Chunk[K, V]): string =
    ## Dumps the internal state of this chunk
    result.add("(size: " & $chunk.size & ", consumed: " & $chunk.consumedCapacity.load & "){")
    var isFirst = true
    for i in 0..<chunk.size:
        if isFirst: isFirst = false else: result.add(", ")
        let item = Entry[K, V](chunk.entries[i])
        result.add("#" & $i & " ")
        result.add(item.dump())
        if item.isState(UsedKey):
            result.add(" (best = " & $chunk.bestIndex(item.key) & ") ")
    result.add("}")

proc needsResize*[K, V](chunk: ptr Chunk[K, V]): bool =
    ## Returns whether the table requires resizing
    chunk.consumedCapacity.load > chunk.size

iterator indexes[K, V](chunk: ptr Chunk[K, V], startKey: K): uint64 =
    ## Iterates through the indexes for testing a key
    let start = chunk.bestIndex(startKey)
    let chunkSize = chunk.size.uint64
    assert(chunkSize > 0, "Invalid chunk size! " & $chunkSize)

    for i in start..<chunkSize:
        yield i
    for i in 0..<start:
        yield i

template track(tracker: var Atomic[int], exec: untyped) =
    ## Uses an atomic integer to track entrance and exits from a block
    tracker.atomicInc()
    try:
        exec
    finally:
        tracker.atomicDec()

template update[K, V](chunk: ptr Chunk[K, V], idx: uint64, existing: var Entry[K, V], newValue: Entry[K, V]): bool =
    ## Updates the given index
    chunk.entries[idx].compareExchange(existing.int64, newValue.int64, Relaxed)

proc writeTo[K, V](chunk: ptr Chunk[K, V], idx: uint64, key: K, value: V, existing: var Entry[K, V]): bool {.inline.} =
    ## Writes a key/value to a specific index, asserting the value of an existing entry
    if chunk.update(idx, existing, encode(key, value, UsedKey)):
        chunk.consumedCapacity.atomicInc()
        true
    else:
        false

proc set*[K, V](chunk: ptr Chunk[K, V], key: K, value: V, overwrite: static ExistingKeyMode = OverwriteExisting): bool =
    ## Set a value in a chunk. Returns whether the set was successful

    chunk.activeWriters.track:
        while true:
            block restart:
                for idx in chunk.indexes(key):
                    var existing = Entry[K, V](chunk.entries[idx])
                    if existing.isWritable:
                        if chunk.writeTo(idx, key, value, existing):
                            return true
                    elif existing.key == key:
                        when overwrite == SkipOnExisting:
                            return true
                        elif overwrite == RaiseOnExisting:
                            raise newException(KeyError, "Index already exists: " & $key)
                        elif overwrite == OverwriteExisting:
                            if chunk.writeTo(idx, key, value, existing):
                                return true
                            else:
                                break restart

                return false

proc del*[K, V](chunk: ptr Chunk[K, V], key: K) =
    ## Deletes a key
    chunk.activeWriters.track:
        while true:
            block restart:
                for idx in chunk.indexes(key):
                    var existing = Entry[K, V](chunk.entries[idx])
                    if existing.isState(UsedKey) and existing.key == key:
                        if not chunk.update(idx, existing, encode[K, V](0, 0, TombstonedKey)):
                            break restart
                    elif existing.isState(UnusedKey):
                        return
                return

const searchMask = usedBit or maxValue.int64

template read*[K, V](chunk: ptr Chunk[K, V], readKey: K, onFound, onMissing) =
    var currentChunk = chunk
    while currentChunk != nil:

        track(currentChunk.activeReaders):

            let searchTarget = readKey.int64 or usedBit

            for idx in indexes(currentChunk, readKey):
                var item {.inject.} = Entry[K, V](currentChunk.entries[idx])
                if (item.int64 and searchMask) == searchTarget:
                    return onFound
                elif isState(item, UnusedKey):
                    break

        currentChunk = load(currentChunk.oldChunk)

    onMissing

proc get*[K, V](chunk: ptr Chunk[K, V], key: K): V =
    ## Reads a key
    read(chunk, key):
        item.value
    do:
        raise newException(KeyError, "Key does not exist: " & $key)

proc maybeGet*[K, V](chunk: ptr Chunk[K, V], key: K): Option[V] =
    ## Reads a key if it exists
    read(chunk, key):
        some(item.value)
    do:
        return none(V)

proc contains*[K, V](chunk: ptr Chunk[K, V], key: K): bool =
    ## Reads whether a key exists in a chunk
    read(chunk, key):
        true
    do:
        return false
