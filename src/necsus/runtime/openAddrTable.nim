import threading/atomics, threading/smartptrs, hashes, strutils, math, locks

##
## Entry encoding
##

type
    SmallValue = int8 | int16 | int32 | bool | enum | uint8 | uint16 | uint32
        ## The keys must keep values under 32b so we can squeeze them into an Atomic value

    EntryState = enum UsedKey, UnusedKey, TombstonedKey
        ## The various states a saved entry can be in

    Entry[K, V] = distinct int64
        ## An entry in the table

## The bit to mark in a key when it is used
const usedBit: int64 = 1 shl 63

## The bit to mark in a key when it is tombstoned
const tombstoneBit: int64 = 1 shl 62

## The maximum value that can be stored in a key
const maxValue: uint32 = not (1.uint32 shl 31)

## All possible metadata bits are set
const allBits: int64 = (usedBit or tombstoneBit)

## A mask that can be used to clear all metadata bits
const clearFlagsMask: int64 = not allBits

proc encode[K: SmallValue, V: SmallValue](key: K, value: V, state: static EntryState): Entry[K, V] {.inline.} =
    ## Encodes a key and value into an entry
    assert(key.uint32 <= maxValue, "Key is too big to fit in this table: " & $key)
    assert(value.uint32 <= maxValue, "Value is too big to fit in this table: " & $value)

    let metadata: int64 =
        when state == UnusedKey: 0
        elif state == UsedKey: usedBit
        elif state == TombstonedKey: tombstoneBit

    return Entry[K, V](metadata or (value.int64 shl 31) or key.int64)

proc value[K, V](entry: Entry[K, V]): V {.inline.} =
    ## Pulls the value out of an entry
    V((entry.int64 and clearFlagsMask) shr 31)

proc key[K, V](entry: Entry[K, V]): K =
    ## Pulls the value out of an entry
    K(entry.int64 and maxValue.int64)

proc isState[K, V](entry: Entry[K, V], state: static[EntryState]): bool {.inline.} =
    ## Returns whether a key is currently considered "in use"
    when state == UsedKey: (entry.int64 and usedBit) != 0
    elif state == TombstonedKey: (entry.int64 and tombstoneBit) != 0
    elif state == UnusedKey: (entry.int64 and allBits) == 0

proc isWritable[K, V](entry: Entry[K, V]): bool {.inline.} =
    ## Returns whether a key is available to be written to
    (entry.int64 and allBits) != usedBit

proc `$`[K, V](entry: Entry[K, V]): string =
    ## Stringify an entry
    $entry.key & ": " & $entry.value

proc dump[K, V](entry: Entry[K, V]): string =
    ## Stringify an entry
    if entry.isState(UsedKey): return $entry
    elif entry.isState(TombstonedKey): return "T"
    elif entry.isState(UnusedKey): return "X"

converter toInt64[K, V](entry: Entry[K, V]): int64 = entry.int64

##
## Chunk
##

type
    Chunk[K, V] = object
        ## A block of values in the map
        size: int
        consumedCapacity: Atomic[int]
        activeReaders: Atomic[int]
        activeWriters: Atomic[int]
        oldChunk: Atomic[ptr Chunk[K, V]]
        entries: UncheckedArray[Atomic[int64]]

proc newChunk[K: SmallValue, V: SmallValue](minSize: int): ptr Chunk[K, V] =
    let size = max(minSize.nextPowerOfTwo, 64)
    let memSize  = sizeof(Chunk[K, V]) + (sizeof(Entry[K, V]) * size)
    result = cast[ptr Chunk[K, V]](allocShared(memSize))
    result.zeroMem(memSize)
    result.size = size

proc `=copy`*[K, V](dest: var Chunk[K, V], src: Chunk[K, V]) {.error.}

iterator items[K, V](chunk: ptr Chunk[K, V]): Entry[K, V] =
    ## Iterate through all used keys and values in a chunk
    for i in 0..<chunk.size:
        let entry = Entry[K, V](chunk.entries[i])
        if entry.isState(UsedKey):
            yield entry

proc `$`[K, V](chunk: ptr Chunk[K, V]): string =
    ## Stringifies a chunk
    var isFirst = true
    for entry in chunk:
        if isFirst: isFirst = false else: result.add(", ")
        result.add($entry)

proc bestIndex[K, V](chunk: ptr Chunk[K, V], key: K): uint64 =
    ## Returns the best index a key can be at for a given chunk
    key.hash.uint64 mod (chunk.size - 1).uint64

proc dump[K, V](chunk: ptr Chunk[K, V]): string =
    ## Dumps the internal state of this chunk
    result.add("(size: " & $chunk.size & ", consumed: " & $chunk.consumedCapacity.load & "){")
    var isFirst = true
    for i in 0..<chunk.size:
        if isFirst: isFirst = false else: result.add(", ")
        let entry = Entry[K, V](chunk.entries[i])
        result.add("#" & $i & " ")
        result.add(entry.dump())
        if entry.isState(UsedKey):
            result.add(" (best = " & $chunk.bestIndex(entry.key) & ") ")
    result.add("}")

proc needsResize[K, V](chunk: ptr Chunk[K, V]): bool =
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

proc set[K, V](chunk: ptr Chunk[K, V], key: K, value: V, overwrite: static bool = true): bool =
    ## Set a value in a chunk. Returns whether the set was successful

    template writeTo(idx: uint64, existing: var Entry[K, V]): bool =
        if chunk.update(idx, existing, encode(key, value, UsedKey)):
            chunk.consumedCapacity.atomicInc()
            true
        else:
            false

    chunk.activeWriters.track:
        while true:
            block restart:
                for idx in chunk.indexes(key):
                    var existing = Entry[K, V](chunk.entries[idx])
                    if existing.isWritable:
                        if writeTo(idx, existing):
                            return true
                    elif existing.key == key:
                        if not overwrite:
                            return true
                        elif writeTo(idx, existing):
                            return true
                        else:
                            break restart

                return false

proc del[K, V](chunk: ptr Chunk[K, V], key: K) =
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

template read[K, V](chunk: ptr Chunk[K, V], readKey: K, onFound, onMissing, recurse: untyped) =
    if chunk == nil:
        onMissing

    track(chunk.activeReaders):

        let searchTarget = readKey.int64 or usedBit

        for idx in indexes(chunk, readKey):
            var entry {.inject.} = Entry[K, V](chunk.entries[idx])
            if (entry.int64 and searchMask) == searchTarget:
                return onFound
            elif isState(entry, UnusedKey):
                break

        return recurse

proc get[K, V](chunk: ptr Chunk[K, V], key: K): V =
    ## Reads a key
    read(chunk, key):
        entry.value
    do:
        raise newException(KeyError, "Key does not exist: " & $key)
    do:
        chunk.oldChunk.load.get(key)

proc contains[K, V](chunk: ptr Chunk[K, V], key: K): bool =
    ## Reads whether a key exists in a chunk
    read(chunk, key):
        true
    do:
        return false
    do:
        chunk.oldChunk.load.contains(key)

##
## OpenAddrTable
##

type
    OpenAddrTable*[K, V] {.byref.} = object
        primaryChunk: Atomic[ptr Chunk[K, V]]
        resizeLock: Lock

proc newOpenAddrTable*[K: SmallValue, V: SmallValue](initialSize: int): OpenAddrTable[K, V] =
    ## Instantiates a new OpenAddrTable
    result.primaryChunk.store(newChunk[K, V](initialSize))
    initLock(result.resizeLock)

proc `=copy`*[K, V](dest: var OpenAddrTable[K, V], src: OpenAddrTable[K, V]) {.error.}

proc awaitClear(tracker: var Atomic[int]) =
    # Spins until a tracker is considered clear
    while tracker.load > 0: discard

proc embiggen[K, V](table: var OpenAddrTable[K, V]) =
    ## Increases the capacity of this table
    withLock table.resizeLock:
        let existingChunk = table.primaryChunk.load

        # Immediately return if it looks like we already resized the table
        if existingChunk.consumedCapacity.load < floorDiv(existingChunk.size, 2):
            return

        # Create a new chunk
        var chunk = newChunk[K, V](existingChunk.size + 1)
        chunk.oldChunk.store(existingChunk)
        table.primaryChunk.store(chunk)

        # Wait for any existing writes to finish so we know we have the full data set
        existingChunk.activeWriters.awaitClear()

        # Copy any old values over to the new chunk
        for entry in existingChunk.items:
            assert(chunk.set(entry.key, existingChunk.get(entry.key), false), "Could not copy an existing value")

        # Detach the old chunk
        chunk.oldChunk.store(nil)

        # Wait for all reads to complete on the old chunk and release the old memory
        existingChunk.activeReaders.awaitClear()
        existingChunk.deallocShared

proc `[]=`*[K, V](table: var OpenAddrTable[K, V], key: K, value: V) =
    ## Set a value
    if table.primaryChunk.load.needsResize or (not table.primaryChunk.load.set(key, value)):
        table.embiggen()
        table[key] = value

proc del*[K, V](table: var OpenAddrTable[K, V], key: K) =
    ## Deletes a value
    table.primaryChunk.load.del(key)

proc `[]`*[K, V](table: var OpenAddrTable[K, V], key: K): V =
    ## Fetch a value
    table.primaryChunk.load.get(key)

proc contains*[K, V](table: var OpenAddrTable[K, V], key: K): bool =
    ## Tests whether a value is in a table
    table.primaryChunk.load.contains(key)

proc `$`*[K, V](table: var OpenAddrTable[K, V]): string = "{" & $table.primaryChunk.load & "}"
    ## Stringify an OpenAddrTable

proc dump*[K, V](table: var OpenAddrTable[K, V]): string =
    ## Dumps the internal state of the table
    table.primaryChunk.load.dump()
