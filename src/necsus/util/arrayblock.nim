
type
    ArrayBlockImpl = object
        size: uint
        data: pointer

    ArrayBlock*[T] = distinct ArrayBlockImpl
        ## A wrapper around UncheckedArray

proc newArrayBlock*[T](len: SomeInteger): ArrayBlock[T] {.inline.}=
    ## Create a new array block
    return ArrayBlock[T](ArrayBlockImpl(size: len.uint, data: allocShared0(uint(sizeof(T)) * len.uint)))

template data[T](ary: ArrayBlock[T]): ptr UncheckedArray[T] = cast[ptr UncheckedArray[T]](ArrayBlockImpl(ary).data)

template size[T](ary: ArrayBlock[T]): uint = ArrayBlockImpl(ary).size

template destructor(ary) =
    if ary.data != nil:
        for i in 0..<ary.size:
            `=destroy`(ary.data[i])
        deallocShared(ary.data)

when NimMajor < 2:
    proc `=destroy`*[T](ary: var ArrayBlock[T]) = destructor(ary)
else:
    proc `=destroy`*[T](ary: ArrayBlock[T]) = destructor(ary)

proc `=copy`*[T](target: var ArrayBlock[T], source: ArrayBlock[T]) {.error.}

proc `=sink`*[T](target: var ArrayBlock[T], source: ArrayBlock[T]) =
    ArrayBlockImpl(target).size = source.size
    ArrayBlockImpl(target).data = source.data

proc isNil*[T](ary: ArrayBlock[T]): bool {.inline.} =
    ## Whether an array block has been initialized
    ary.data == nil

proc del*[T](ary: var ArrayBlock[T], index: SomeInteger): T =
    ## Deletes a value from this array and returns the deleted value
    result = move(ary.data[index.uint])

template checkBounds[T](ary: ArrayBlock[T], index: SomeInteger) =
    when compileOption("boundChecks"):
        if index < 0 or index.uint >= ary.size:
            raise newException(IndexDefect, $index & " is out of bounds")

proc `[]`*[T](ary: ArrayBlock[T], index: SomeInteger): var T {.inline.} =
    ## Read a value from this array block
    ary.checkBounds(index.uint)
    ary.data[index.uint]

proc `[]=`*[T](ary: ArrayBlock[T], index: SomeInteger, value: sink T) {.inline.} =
    ## Write a value to this array block
    ary.checkBounds(index.uint)
    ary.data[index.uint] = value

iterator items*[T](ary: var ArrayBlock[T]): var T =
    ## Iterate through all values in this array
    for i in 0..<ary.size:
        yield ary.data[i]
