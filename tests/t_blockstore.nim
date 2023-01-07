import unittest, necsus/util/blockstore, sequtils

suite "BlockStore":

    test "Pushing values":
        var store = newBlockStore[string](50)

        let id1 = store.push("foo")
        check(store[id1] == "foo")
        check(store.items.toSeq == @["foo"])

        let id2 = store.push("bar")
        check(store[id1] == "foo")
        check(store[id2] == "bar")
        check(store.items.toSeq == @["foo", "bar"])

        let id3 = store.push("baz")
        check(store[id1] == "foo")
        check(store[id2] == "bar")
        check(store[id3] == "baz")
        check(store.items.toSeq == @["foo", "bar", "baz"])

    test "Deleting values":
        var store = newBlockStore[int](50)

        let id0 = store.push(0)
        let id1 = store.push(1)
        let id2 = store.push(2)
        let id3 = store.push(3)

        check(store.items.toSeq == @[0, 1, 2, 3])

        store.del(id2)
        check(store.items.toSeq == @[0, 1, 3])

        store.del(id0)
        check(store.items.toSeq == @[1, 3])

        store.del(id3)
        check(store.items.toSeq == @[1])

        store.del(id1)
        check(store.items.toSeq == newSeq[int]())

    test "Fail when indexes are out of bounds":
        var store = newBlockStore[string](5)

        for i in 1..5:
            discard store.push("foo")

        expect IndexDefect:
            discard store.push("foo")

        expect IndexDefect:
            store.del(50)

        expect IndexDefect:
            discard store[50]

    test "Re-using deleted slots":
        var store = newBlockStore[int](10)
        for i in 0..100:
            let idx = store.push(i)
            check(store[idx] == i)
            store.del(idx)

    test "Reserving values":
        var store = newBlockStore[string](50)

        let id1 = store.reserve do (index: uint, value: var string) -> void:
            check(index == 0)
            value = "foo"

        check(store[id1] == "foo")
        check(store.items.toSeq == @["foo"])

        let id2 = store.reserve do (index: uint, value: var string) -> void:
            check(index == 1)
            value = "bar"
        check(store[id2] == "bar")
        check(store.items.toSeq == @["foo", "bar"])
