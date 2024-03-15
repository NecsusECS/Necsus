import unittest, necsus/util/arrayblock, sequtils

type
    ExampleValue = object
        value: int

    DeleteCounted = object
        initialized: bool

proc `=copy`(a: var ExampleValue, b: ExampleValue) {.error.}

var deleteCount = 0

template destructor(value) =
    if value.initialized:
        assert(deleteCount <= 1)
        deleteCount += 1

when NimMajor < 2:
    proc `=destroy`(value: var DeleteCounted) = destructor(value)
else:
    proc `=destroy`(value: DeleteCounted) = destructor(value)

suite "Array blocks":
    test "Array blocks should allow values to be added and deleted":

        var ary = newArrayBlock[ExampleValue](10)
        ary[0] = ExampleValue(value: 10)
        ary[1] = ExampleValue(value: 20)
        ary[2] = ExampleValue(value: 30)

        check(ary[0].value == 10)
        check(ary[1].value == 20)
        check(ary[2].value == 30)

        let deleted = ary.del(0)
        check(deleted.value == 10)
        check(ary[0].value == 0)

    test "Array blocks should iterate over values":

        var ary = newArrayBlock[ExampleValue](5)
        ary[0] = ExampleValue(value: 10)
        ary[1] = ExampleValue(value: 20)
        ary[2] = ExampleValue(value: 30)

        check(ary.mapIt(it.value) == @[10, 20, 30, 0, 0])

    test "Deleting a value should only call destroy once":
        block:
            var ary = newArrayBlock[DeleteCounted](1)
            ary[0] = DeleteCounted(initialized: true)
            discard ary.del(0)
        check(deleteCount == 1)