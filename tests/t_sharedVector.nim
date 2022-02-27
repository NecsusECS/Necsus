import unittest, necsus/util/sharedVector, sequtils

suite "SharedVector":

    test "Setting and getting values":
        var storage = newSharedVector[uint](100_000)

        for i in 1'u..20:
            storage[i] = i
            require(storage[i] == i)

        for i in 1'u..20:
            require(storage[i] == i)

    test "Storage resizing":
        var storage = newSharedVector[uint](10)

        for i in 1'u..100_000:
            storage[i] = i

        for i in 1'u..100_000:
            check(storage[i] == i)

    test "mget":
        var storage = newSharedVector[string](1_000)
        storage[20] = "foo"
        storage.mget(20).add("bar")
        check(storage[20] == "foobar")

    test "mget should resize":
        var storage = newSharedVector[string](1_000)
        storage.mget(20_000).add("foobar")
        check(storage[20_000] == "foobar")

    test "items":
        var storage = newSharedVector[uint](1_000)
        for i in 0'u..10:
            storage[i] = i

        var found = storage.toSeq
        found.setLen(10)
        check(found == @[ 0'u, 1, 2, 3, 4, 5, 6, 7, 8, 9 ])
