import macros, sync/spinlock

##
## Resizable array of values stored in large buckets of memory. The benefit of this
## over using a resizable array is that values don't change their address when the
## array gets resized. Only acquires a lock when resizing.
##
## Based on https://philosopherdeveloper.com/posts/how-to-build-a-thread-safe-lock-free-resizable-array.html
##

type
    SharedVector*[T] {.byref.} = object
        ## Resizable vector of values
        resizeLock: SpinLock # A SpinLock to work around: https://github.com/nim-lang/Nim/issues/14873
        size: uint
        buckets: array[32, ptr UncheckedArray[T]]

proc `=copy`*[T](dest: var SharedVector[T], src: SharedVector[T]) {.error.}

iterator bucketDetails*[T](vector: SharedVector[T]): tuple[index: uint, size: uint] =
    ## Iterate through all the used buckets in this vector, along with their length
    var bucketSize = 1'u
    for bucket in 0'u..<len(vector.buckets):

        if vector.buckets[bucket] == nil:
            break

        yield (bucket, bucketSize)

        bucketSize *= 2

proc `=destroy`*[T](vector: var SharedVector[T]) =
    for (bucket, bucketSize) in vector.bucketDetails:
        for index in 0..<bucketSize:
            `=destroy`(vector.buckets[bucket][index])
        deallocShared(vector.buckets[bucket])

proc allocateArray(typ: typedesc, len: uint): ptr UncheckedArray[typ] =
    let memsize = uint(sizeof(typ)) * len
    let mem = allocShared(memsize)
    mem.zeroMem(memsize)
    result = cast[ptr UncheckedArray[typ]](mem)

proc reserve*[T](vector: var SharedVector[T], size: uint) =
    ## Ensures this vector can hold at least the given number of elements

    vector.resizeLock.withLock:

        var allocated = 0'u
        var bucket = 0'u
        var bucketSize = 1'u

        while allocated <= size:
            if vector.buckets[bucket] == nil:
                vector.buckets[bucket] = allocateArray(T, bucketSize)
            allocated += bucketSize
            bucket += 1
            bucketSize *= 2

        vector.size = allocated

proc newSharedVector*[T](initialSize: uint): SharedVector[T] =
    ## Instantiate a new vector
    result.size = 0
    result.reserve(initialSize)

proc len*[T](vector: SharedVector[T]): uint =
    ## Returns the size of this vector
    vector.size

macro generateKeyToBucketTable(): untyped =
    ## Creates a lookup table that maps a key back to the bucket its in. This is equivalent
    ## to the following code: int(log2(key.float + 1))
    let keyNode: NimNode = ident("key")
    result = nnkCaseStmt.newTree(keyNode)

    var bucketSize = 1'u
    var accum = 0'u
    for bucket in 0'u..<32:
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
    let index = key - (1'u shl bucket) + 1

    if vector.buckets[bucket] == nil:
        when allowResize:
            reserve(vector, key)
        elif compileOption("boundChecks"):
            raise newException(IndexDefect, $key & " is out of bounds (in bucket " & $bucket & ")")
        else:
            discard

    vector.buckets[bucket][index]

proc `[]=`*[T](vector: var SharedVector[T], key: uint, value: sink T) =
    ## Set a value
    entryRef(vector, key, true) = value

proc `[]`*[T](vector: SharedVector[T], key: uint): lent T =
    ## Returns a value
    entryRef(vector, key, false)

proc `[]`*[T](vector: var SharedVector[T], key: uint): var T =
    ## Returns a value
    entryRef(vector, key, false)

proc mget*[T](vector: var SharedVector[T], key: uint): var T =
    ## Returns a mutable reference to a value
    entryRef(vector, key, true)

iterator items*[T](vector: SharedVector[T]): lent T =
    ## Iterate through all values in this vector
    for (bucket, bucketSize) in vector.bucketDetails:
        for index in 0..<bucketSize:
            yield vector.buckets[bucket][index]
