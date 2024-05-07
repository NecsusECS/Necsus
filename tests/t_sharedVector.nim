import unittest, necsus/util/sharedVector, sequtils

suite "SharedVector":

    test "Setting and getting values":
        var storage: SharedVector[uint]
        storage.reserve(1000)

        for i in 1'u..20:
            storage[i] = i
            require(storage[i] == i)

        for i in 1'u..20:
            require(storage[i] == i)

    test "Storage resizing":
        var storage: SharedVector[uint]

        for i in 1'u..100_000:
            storage[i] = i

        for i in 1'u..100_000:
            check(storage[i] == i)

    test "mget":
        var storage: SharedVector[string]
        storage[20] = "foo"
        storage.mget(20).add("bar")
        check(storage[20] == "foobar")

    test "mget should resize":
        var storage: SharedVector[string]
        storage.mget(20_000).add("foobar")
        check(storage[20_000] == "foobar")

    test "items":
        var storage: SharedVector[uint]
        for i in 0'u..30:
            storage[i] = i

        var found = storage.toSeq
        found.setLen(30)
        check(found == @[
            0'u, 1, 2, 3, 4, 5, 6, 7, 8, 9,
            10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
            20, 21, 22, 23, 24, 25, 26, 27, 28, 29
        ])

    test "vector len":
        var storage: SharedVector[string]
        check(storage.len == 7)

        storage.reserve(6)
        check(storage.len == 7)

        storage.reserve(7)
        check(storage.len == 15)

        storage.reserve(20)
        check(storage.len == 31)

        storage.reserve(500)
        check(storage.len == 511)

        storage.reserve(10_000)
        check(storage.len == 16383)