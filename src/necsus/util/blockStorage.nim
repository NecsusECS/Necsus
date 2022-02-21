import locks, strformat, math

#
# BlockStorage
#

const Size = 16_384

type
    Bucket[T] = ref object
        entries: array[Size, T]

    BlockStorage*[T] = object
        ## Linked list of storage for table values
        buckets: seq[Bucket[T]]

# Making this global is a temporary work-around for https://github.com/nim-lang/Nim/issues/14873
var resizeLock: Lock
resizeLock.initLock()

proc ensureSize[T](buckets: var seq[Bucket[T]], size: int) =
    if size > buckets.len:
        resizeLock.withLock:
            let currentSize = buckets.len
            buckets.setLen(size)
            for i in currentSize..<size:
                buckets[i].new

proc newBlockStorage*[T](initialSize: int): BlockStorage[T] =
    ## Instantiate new storage
    result.buckets.ensureSize(ceilDiv(initialSize, Size))

proc bucketIndex(key: int): int {.inline.} =
    ## Returns the bucket index for a given key
    key div Size

proc bucketKey(key, bucketIndex: int): int {.inline.} =
    ## Returns the key within a bucket
    key - (bucketIndex * Size)

proc `[]=`*[T](storage: var BlockStorage[T], key: int, value: T) =
    ## Set a value
    let bucketIdx = key.bucketIndex
    storage.buckets.ensureSize(bucketIdx + 1)
    storage.buckets[bucketIdx].entries[bucketKey(key, bucketIdx)] = value

proc `[]`*[T](storage: BlockStorage[T], key: int): lent T =
    ## Returns a value
    let bucketIdx = bucketIndex(key)
    if bucketIdx >= storage.buckets.len:
        raise newException(IndexDefect, &"Index is out of bounds: {key}")
    return storage.buckets[bucketIdx].entries[bucketKey(key, bucketIdx)]

proc mget*[T](storage: var BlockStorage[T], key: int): var T =
    ## Returns a mutable reference to a value
    let bucketIdx = key.bucketIndex
    storage.buckets.ensureSize(bucketIdx + 1)
    return storage.buckets[bucketIdx].entries[bucketKey(key, bucketIdx)]

iterator items*[T](storage: BlockStorage[T], maxIndex: int): lent T =
    ## Iterate through all values in this storage, up to the given index
    var accum = 0
    for bucket in storage.buckets:
        for i in 0..<Size:
            if accum >= maxIndex:
                break
            accum = accum + 1
            yield bucket.entries[i]
