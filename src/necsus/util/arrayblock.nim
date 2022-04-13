
type ArrayBlock*[T] = object
    ## A wrapper around UncheckedArray
    size: uint
    data: ptr UncheckedArray[T]

proc newArrayBlock*[T](len: SomeInteger): ArrayBlock[T] =
    ## Create a new array block
    result.size = len.uint
    result.data = cast[ptr UncheckedArray[T]](allocShared0(uint(sizeof(T)) * len.uint))

proc `=destroy`*[T](ary: var ArrayBlock[T]) =
    if ary.data != nil:
        for i in 0..<ary.size:
            `=destroy`(ary.data[i])
        deallocShared(ary.data)

proc `=copy`*[T](target: var ArrayBlock[T], source: ArrayBlock[T]) {.error.}

proc `=sink`*[T](target: var ArrayBlock[T], source: ArrayBlock[T]) =
    target.size = source.size
    target.data = source.data

proc isNil*[T](ary: ArrayBlock[T]): bool {.inline.} =
    ## Whether an array block has been initialized
    ary.data == nil

template checkBounds[T](ary: ArrayBlock[T], index: SomeInteger) =
    when compileOption("boundChecks"):
        if index < 0 or index >= ary.size:
            raise newException(IndexDefect, $index & " is out of bounds")

proc `[]`*[T](ary: ArrayBlock[T], index: SomeInteger): var T {.inline.} =
    ## Read a value from this array block
    ary.checkBounds(index)
    ary.data[index]

proc `[]=`*[T](ary: ArrayBlock[T], index: SomeInteger, value: sink T) {.inline.} =
    ## Write a value to this array block
    ary.checkBounds(index)
    ary.data[index] = value

iterator items*[T](ary: var ArrayBlock[T]): var T =
    ## Iterate through all values in this array
    for i in 0..<ary.size:
        yield ary.data[i]
