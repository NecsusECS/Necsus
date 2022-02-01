import locks, strformat

#
# BlockStorage
#

const Size = 16_384

type
    BlockStorage*[T] = ref object
        ## Linked list of storage for table values
        entries: array[Size, T]
        nextLock: Lock
        next: BlockStorage[T]

proc newBlockStorage*[T](): BlockStorage[T] =
    ## Instantiate new storage
    result.new
    result.nextLock.initLock()

proc `[]=`*[T](storage: var BlockStorage[T], key: int, value: T) {.inline.} =
    ## Set a value
    if key < Size:
        storage.entries[key] = value
    else:
        if storage.next == nil:
            storage.nextLock.withLock:
                if storage.next == nil:
                    storage.next = newBlockStorage[T]()

        storage.next[key - Size] = value

template getter[T](storage: BlockStorage[T], key: int, recurse: untyped) =
    ## Generate getter code
    if key < Size:
        return storage.entries[key]
    elif storage.next != nil:
        return recurse(storage.next, key - Size)
    else:
        raise newException(IndexDefect, &"Index is out of bounds: {key}")

proc `[]`*[T](storage: BlockStorage[T], key: int): lent T {.inline.} =
    ## Returns a value
    getter(storage, key, `[]`)

proc mget*[T](storage: var BlockStorage[T], key: int): var T {.inline.} =
    ## Returns a mutable reference to a value
    getter(storage, key, mget)

iterator items*[T](storage: BlockStorage[T], maxIndex: int): lent T =
    ## Iterate through all values in this storage, up to the given index

    var count = maxIndex
    var currentStorage: BlockStorage[T] = storage

    while true:
        for i in 0..<min(count, Size):
            yield currentStorage.entries[i]

        if count < Size or currentStorage.next == nil:
            break

        currentStorage = currentStorage.next
        count = count - Size
