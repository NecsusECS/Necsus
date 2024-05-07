import macros, threads

##
## Resizable array of values stored in large buckets of memory. The benefit of this
## over using a resizable array is that values don't change their address when the
## array gets resized. Only acquires a lock when resizing.
##
## Based on https://philosopherdeveloper.com/posts/how-to-build-a-thread-safe-lock-free-resizable-array.html
##

# Preallocate a certain number of slots
const PREALLOC_SIZE = 7'u

# The number of dynamic buckets to create
const DYN_BUCKETS = 29

type
    SharedVector*[T] {.byref.} = object
        ## Resizable vector of values
        resizeLock: Lock
        size: uint
        prealloc: array[PREALLOC_SIZE, T]
        buckets: array[DYN_BUCKETS, seq[T]]

proc `=copy`*[T](dest: var SharedVector[T], src: SharedVector[T]) {.error.}

proc `=sink`*[T](dest: var SharedVector[T], src: SharedVector[T]) =
    dest.size = src.size
    `=sink`(dest.prealloc, src.prealloc)
    for i in 0'u..<len(src.buckets):
        `=sink`(dest.buckets[i], src.buckets[i])

proc reserve*[T](vector: var SharedVector[T], size: uint) =
    ## Ensures this vector can hold at least the given number of elements

    vector.resizeLock.withLock:

        var allocated = PREALLOC_SIZE
        var bucket = 0'u
        var bucketSize = PREALLOC_SIZE + 1

        while allocated <= size:
            if vector.buckets[bucket].len == 0:
                vector.buckets[bucket] = newSeq[T](bucketSize)
            allocated += bucketSize
            bucket += 1
            bucketSize *= 2

        vector.size = allocated - PREALLOC_SIZE

proc len*[T](vector: SharedVector[T]): uint =
    ## Returns the size of this vector
    vector.size + PREALLOC_SIZE

macro generateKeyToBucketTable(): untyped =
    ## Creates a lookup table that maps a key back to the bucket its in. This is equivalent
    ## to the following code: int(log2(key.float + 1))
    let keyNode: NimNode = ident("key")
    result = nnkCaseStmt.newTree(keyNode)

    var bucketSize = PREALLOC_SIZE + 1
    var accum = PREALLOC_SIZE
    for bucket in 0'u..<DYN_BUCKETS:
        let first = accum
        let last = accum + bucketSize - 1
        result.add(
            nnkOfBranch.newTree(
                nnkInfix.newTree(ident(".."), newLit(first), newLit(last)),
                nnkStmtList.newTree(nnkReturnStmt.newTree(newLit(bucket)))
            )
        )
        accum += bucketSize
        bucketSize *= 2

    result.add(nnkElse.newTree(nnkStmtList.newTree(nnkReturnStmt.newTree(newLit(0'u)))))

proc determineBucket(key: uint): uint =
    ## Returns the bucket index for a key
    generateKeyToBucketTable()

template entryRef[T](vector: SharedVector[T], key: uint, allowResize: static bool): untyped =
    let bucket = determineBucket(key)
    let index = key - (1'u shl (bucket + 32 - DYN_BUCKETS)) + 1

    if vector.buckets[bucket].len == 0:
        when allowResize:
            reserve(vector, key)
        elif compileOption("boundChecks"):
            raise newException(IndexDefect, $key & " is out of bounds (in bucket " & $bucket & ")")
        else:
            discard

    vector.buckets[bucket][index]

proc `[]=`*[T](vector: var SharedVector[T], key: uint, value: sink T) =
    ## Set a value
    if key < PREALLOC_SIZE:
        vector.prealloc[key] = value
    else:
        entryRef(vector, key, true) = value

proc `[]`*[T](vector: SharedVector[T], key: uint): lent T =
    ## Returns a value
    if key < PREALLOC_SIZE:
        return vector.prealloc[key]
    else:
        return entryRef(vector, key, false)

proc `[]`*[T](vector: var SharedVector[T], key: uint): var T =
    ## Returns a value
    if key < PREALLOC_SIZE:
        return vector.prealloc[key]
    else:
        return entryRef(vector, key, false)

proc mget*[T](vector: var SharedVector[T], key: uint): var T =
    ## Returns a mutable reference to a value
    if key < PREALLOC_SIZE:
        return vector.prealloc[key]
    else:
        return entryRef(vector, key, true)

iterator items*[T](vector: SharedVector[T]): lent T =
    ## Iterate through all values in this vector
    for i in 0..<PREALLOC_SIZE:
        yield vector.prealloc[i]

    for bucketId in 0..<len(vector.buckets):
        let bucketLen = len(vector.buckets[bucketId])
        if bucketLen == 0:
            break
        for idx in 0..<bucketLen:
            yield vector.buckets[bucketId][idx]
