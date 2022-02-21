import blockStorage, threading/atomics

##
## Packed list of values. Deleting entries will cause the existing values
## to re-order themselves so that they stay packed
##

type
    PackedList*[T] = object
        ## A list of values that stays packed in memory
        entries: BlockStorage[T]
        maxIndex: Atomic[int]

proc newPackedList*[T](initialSize: int): PackedList[T] =
    ## Create a new PackedList
    result.entries = newBlockStorage[T](initialSize)

proc `=copy`*[T](dest: var PackedList[T], src: PackedList[T]) {.error.}

proc len*[T](list: var PackedList[T]): int =
    ## Return the length of this packed list
    list.maxIndex.load

proc push*[T](list: var PackedList[T], value: sink T): int =
    ## Pushes a value onto this list
    result = list.maxIndex.fetchAdd(1)
    list.entries[result] = value

proc `[]=`*[T](list: var PackedList[T], key: int, value: sink T) =
    ## Sets a value in the list at a specific index
    assert(key < list.maxIndex.load)
    list.entries[key] = value

iterator items*[T](list: var PackedList[T]): lent T =
    ## Iterate through all values
    for entry in list.entries.items(list.maxIndex.load()):
        yield entry

proc `[]`*[T](list: var PackedList[T], key: int): var T =
    ## Fetch a value
    assert(key < list.maxIndex.load)
    list.entries.mget(key)

template deleteKey*[T](list: var PackedList[T], key: int; oldValue, onReorder: untyped) =
    ## Removes a value at a specific index
    let newMaxIndex = fetchSub(list.maxIndex, 1) - 1

    # To keep the data packed, move the last element into the deleted slot
    if newMaxIndex > 0 and newMaxIndex != key:
        list.entries[key] = `[]`(list.entries, newMaxIndex)
        var oldValue = addr mget(list.entries, newMaxIndex)
        onReorder

proc clear*[T](list: var PackedList[T]) =
    ## Soft clear of all values from this list
    list.maxIndex.store(0)
