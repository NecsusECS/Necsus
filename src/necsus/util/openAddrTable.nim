import sharedVector, options, threading/atomics, openAddrData, locks

##
## OpenAddrTable
##

type
    OpenAddrTable*[K, V] {.byref.} = object
        previousCapacity: Atomic[uint]
        capacity: Atomic[uint]
        data: OpenAddrData[K, V]

# Global lock to work around https://github.com/nim-lang/Nim/issues/14873
# This should be moved into OpenAddrTable when possible
var resizeLock: Lock
resizeLock.initLock

proc newOpenAddrTable*[K, V](initialSize: SomeInteger): OpenAddrTable[K, V] =
    ## Instantiates a new OpenAddrTable
    result.data = newOpenAddrData[K, V](initialSize.uint)
    result.capacity.store(result.data.capacity)

proc `=copy`*[K, V](dest: var OpenAddrTable[K, V], src: OpenAddrTable[K, V]) {.error.}

proc enlarge[K, V](table: var OpenAddrTable[K, V]) =
    ## Increase the capacity of this table
    resizeLock.withLock:
        let currentCapacity = table.capacity.load

        # Increase the amount of available data space
        table.data.enlarge((currentCapacity * 3) div 2)
        let newCapacity = table.data.capacity

        # Store the size of the new capacity and backlog the size of the old capacity
        table.previousCapacity.store(currentCapacity)
        table.capacity.store(newCapacity)

        table.data.migrate(currentCapacity, newCapacity)

        table.data.cleanup()

        table.previousCapacity.store(newCapacity)

proc setAndRef*[K, V](table: var OpenAddrTable[K, V], key: K, value: sink V): ptr V =
    ## Set a value and returns a pointer to the value
    let (status, location) = write(table.data, key, value, table.capacity.load)
    case status
    of SetSuccess: return location
    of RetrySet: return table.setAndRef(key, value)
    of ResizeNeeded:
        table.enlarge()
        return table.setAndRef(key, value)

proc `[]=`*[K, V](table: var OpenAddrTable[K, V], key: K, value: sink V) =
    ## Set a value
    discard table.setAndRef(key, value)

proc `[]`*[K, V](table: var OpenAddrTable[K, V], key: K): var V =
    ## Fetch a value
    return read(table.data, key, table.capacity, table.previousCapacity)

proc maybeGet*[K, V](table: var OpenAddrTable[K, V], key: K): Option[V] =
    ## Fetch a value if it exists
    return maybeRead(table.data, key, table.capacity, table.previousCapacity)

proc maybeGetPointer*[K, V](table: var OpenAddrTable[K, V], key: K): Option[ptr V] =
    ## Fetch a value if it exists
    return maybeReadPointer(table.data, key, table.capacity, table.previousCapacity)

proc contains*[K, V](table: var OpenAddrTable[K, V], key: K): bool =
    ## Tests whether a value is in a table
    return contains(table.data, key, table.capacity, table.previousCapacity)

proc del*[K, V](table: var OpenAddrTable[K, V], key: K) =
    ## Deletes a value
    del(table.data, key, table.capacity, table.previousCapacity)

proc `$`*[K, V](table: var OpenAddrTable[K, V]): string =
    ## Stringify an OpenAddrTable
    "{" & $table.data & "}"

iterator items*[K, V](table: var OpenAddrTable[K, V]): lent V =
    ## Iterate over the values in this table
    for value in items(table.data):
        yield value

iterator pairs*[K, V](table: var OpenAddrTable[K, V]): (K, V) =
    ## Iterate over the keys and values in this table
    for entry in pairs(table.data):
        yield entry

proc dump*[K, V](table: var OpenAddrTable[K, V]): string =
    ## Dumps the internal state of the table
    "[" & table.data.dump & "]"
