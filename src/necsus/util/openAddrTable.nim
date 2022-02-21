import openAddrEntry, openAddrChunk, threading/atomics, threading/smartptrs, strutils, math, locks, options

##
## OpenAddrTable
##

# Making this global is a temporary work-around for https://github.com/nim-lang/Nim/issues/14873
var resizeLock: Lock
resizeLock.initLock()

type
    OpenAddrTable*[K, V] {.byref.} = object
        primaryChunk: Atomic[ptr Chunk[K, V]]

proc newOpenAddrTable*[K: SmallValue, V: SmallValue](initialSize: int): OpenAddrTable[K, V] =
    ## Instantiates a new OpenAddrTable
    result.primaryChunk.store(newChunk[K, V](initialSize))

proc `=copy`*[K, V](dest: var OpenAddrTable[K, V], src: OpenAddrTable[K, V]) {.error.}

proc awaitClear(tracker: var Atomic[int]) =
    # Spins until a tracker is considered clear
    while tracker.load > 0: discard

proc embiggen[K, V](table: var OpenAddrTable[K, V]) =
    ## Increases the capacity of this table
    withLock resizeLock:
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
        for item in existingChunk.items:
            assert(
                chunk.set(item.key, existingChunk.get(item.key), SkipOnExisting),
                "Could not copy an existing value"
            )

        # Detach the old chunk
        chunk.oldChunk.store(nil)

        # Wait for all reads to complete on the old chunk and release the old memory
        existingChunk.activeReaders.awaitClear()
        existingChunk.deallocShared

proc setValue*[K, V](table: var OpenAddrTable[K, V], key: K, value: V, mode: static ExistingKeyMode) {.inline.} =
    while true:
        if table.primaryChunk.load.needsResize or (not table.primaryChunk.load.set(key, value, mode)):
            table.embiggen()
        else:
            return

proc `[]=`*[K, V](table: var OpenAddrTable[K, V], key: K, value: V) =
    ## Set a value
    table.setValue(key, value, OverwriteExisting)

proc setNew*[K, V](table: var OpenAddrTable[K, V], key: K, value: V) =
    ## Sets a value guaranteed to be new
    table.setValue(key, value, RaiseOnExisting)

proc del*[K, V](table: var OpenAddrTable[K, V], key: K) =
    ## Deletes a value
    table.primaryChunk.load.del(key)
    assert(key notin table.primaryChunk.load)

proc `[]`*[K, V](table: var OpenAddrTable[K, V], key: K): V =
    ## Fetch a value
    table.primaryChunk.load.get(key)

proc maybeGet*[K, V](table: var OpenAddrTable[K, V], key: K): Option[V] =
    ## Fetch a value if it exists
    table.primaryChunk.load.maybeGet(key)

proc contains*[K, V](table: var OpenAddrTable[K, V], key: K): bool =
    ## Tests whether a value is in a table
    table.primaryChunk.load.contains(key)

proc `$`*[K, V](table: var OpenAddrTable[K, V]): string = "{" & $table.primaryChunk.load & "}"
    ## Stringify an OpenAddrTable

proc dump*[K, V](table: var OpenAddrTable[K, V]): string =
    ## Dumps the internal state of the table
    table.primaryChunk.load.dump()
