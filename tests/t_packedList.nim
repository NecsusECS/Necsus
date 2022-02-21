import unittest, necsus/util/packedList, sequtils

suite "PackedList":

    test "Pushing values, reading indexes, reading iterated values":
        var list = newPackedList[int](20)

        for i in 0..10:
            let key = list.push(i)
            check(list[key] == i)

        check(list.toSeq == toSeq(0..10))

    test "Assigning arbitrary indexes":
        var list = newPackedList[int](20)

        for i in 0..10:
            discard list.push(i)

        for i in 0..10:
            list[i] = i + 20

        check(list.toSeq == toSeq(20..30))

    test "Filling past the initial size":
        var list = newPackedList[int](10)

        for i in 0..1_000:
            discard list.push(i)

        check(list.toSeq == toSeq(0..1_000))

    test "Deleting values":
        var list = newPackedList[int](20)
        for i in 0..3:
            discard list.push(i)

        list.deleteKey(1, movedValue):
            check(movedValue[] == 3)
        check(list.toSeq == @[ 0, 3, 2 ])

        list.deleteKey(1, movedValue):
            check(movedValue[] == 2)
        check(list.toSeq == @[ 0, 2 ])

        list.deleteKey(1, _):
            check(false)
        check(list.toSeq == @[ 0 ])

        list.deleteKey(0, _):
            check(false)
        check(list.toSeq.len == 0)

    test "Clearing the list":
        var list = newPackedList[int](20)

        list.clear()
        check(list.toSeq.len == 0)

        for i in 0..3:
            discard list.push(i)
        list.clear()
        check(list.toSeq.len == 0)
