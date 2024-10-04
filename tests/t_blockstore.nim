import unittest, necsus/util/blockstore, sequtils

suite "BlockStore":

    test "Pushing values":
        var store = newBlockStore[string](50)
        check(store.len == 0)

        let id1 = store.push("foo")
        check(store[id1] == "foo")
        check(store.items.toSeq == @["foo"])
        check(store.len == 1)

        let id2 = store.push("bar")
        check(store[id1] == "foo")
        check(store[id2] == "bar")
        check(store.items.toSeq == @["foo", "bar"])
        check(store.len == 2)


        let id3 = store.push("baz")
        check(store[id1] == "foo")
        check(store[id2] == "bar")
        check(store[id3] == "baz")
        check(store.items.toSeq == @["foo", "bar", "baz"])
        check(store.len == 3)

    test "Deleting values":
        var store = newBlockStore[int](50)

        let id0 = store.push(0)
        let id1 = store.push(1)
        let id2 = store.push(2)
        let id3 = store.push(3)

        check(store.items.toSeq == @[0, 1, 2, 3])
        check(store.len == 4)

        check(store.del(id2) == 2)
        check(store.items.toSeq == @[0, 1, 3])
        check(store.len == 3)

        check(store.del(id0) == 0)
        check(store.items.toSeq == @[1, 3])
        check(store.len == 2)

        check(store.del(id3) == 3)
        check(store.items.toSeq == @[1])
        check(store.len == 1)

        check(store.del(id1) == 1)
        check(store.items.toSeq == newSeq[int]())
        check(store.len == 0)

    test "Fail when indexes are out of bounds":
        var store = newBlockStore[string](5)

        for i in 1..5:
            discard store.push("foo")

        expect IndexDefect:
            discard store.push("foo")

        expect IndexDefect:
            discard store.del(50)

        expect IndexDefect:
            discard store[50]

    test "Re-using deleted slots":
        var store = newBlockStore[int](10)
        for i in 0..100:
            let idx = store.push(i)
            check(store[idx] == i)
            discard store.del(idx)

    test "Reserving values":
        var store = newBlockStore[string](50)

        var e1 = store.reserve
        check(e1.index == 0)
        e1.set("foo")
        check(store[e1.index] == "foo")
        check(store.items.toSeq == @["foo"])

        var e2 = store.reserve
        check(e2.index == 1)
        e2.value.add("bar")
        e2.commit
        check(store[e2.index] == "bar")
        check(store.items.toSeq == @["foo", "bar"])

    test "Manual iteration":
        var store = newBlockStore[string](50)
        let id1 = store.push("foo")
        let id2 = store.push("bar")
        let id3 = store.push("baz")

        var iter: BlockIter
        check(store.next(iter)[] == "foo")
        check(store.next(iter)[] == "bar")
        check(store.next(iter)[] == "baz")
        check(store.next(iter) == nil)
