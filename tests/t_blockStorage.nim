import unittest, necsus/util/blockStorage, sequtils

suite "BlockStorage":

    test "Setting and getting values":
        var storage = newBlockStorage[int](1_000)

        for i in 1..20:
            storage[i] = i
            check(storage[i] == i)

        for i in 1..20:
            check(storage[i] == i)

    test "Storage resizing":
        var storage = newBlockStorage[int](1_000)

        for i in 1..100_000:
            storage[i] = i

        for i in 1..100_000:
            check(storage[i] == i)

    test "mget":
        var storage = newBlockStorage[string](1_000)
        storage[20] = "foo"
        storage.mget(20).add("bar")
        check(storage[20] == "foobar")

    test "mget should resize":
        var storage = newBlockStorage[string](1_000)
        storage.mget(20_000).add("foobar")
        check(storage[20_000] == "foobar")

    test "items":
        var storage = newBlockStorage[int](1_000)
        for i in 0..10:
            storage[i] = i

        check(storage.items(10).toSeq == @[ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ])
        check(storage.items(5).toSeq == @[ 0, 1, 2, 3, 4 ])
