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

    for i in 1 .. 5:
      discard store.push("foo")

    expect IndexDefect:
      discard store.push("foo")

    expect IndexDefect:
      discard store.del(50)

    expect IndexDefect:
      discard store[50]

  test "Re-using deleted slots":
    var store = newBlockStore[int](10)
    for i in 0 .. 100:
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

  test "Taking a span of every value":
    var store = newBlockStore[string](50)
    check(store.wholeSpan.isEmpty)
    check(store.wholeSpan.slots == 0)
    check(store.wholeSpan.items(string).toSeq == newSeq[string]())

    discard store.push("foo")
    discard store.push("bar")
    discard store.push("baz")

    let span = store.wholeSpan
    check(not span.isEmpty)
    check(span.slots == 3)
    check(span.items(string).toSeq == @["foo", "bar", "baz"])

  test "Spans point at the values themselves":
    var store = newBlockStore[int](50)
    let id = store.push(7)

    for address in store.wholeSpan.addresses(int):
      check(address == addr store[id])
      address[] = 9

    check(store[id] == 9)

    for value in store.wholeSpan.items(int):
      value = 11

    check(store[id] == 11)

  test "Spans skip deleted values":
    var store = newBlockStore[int](50)
    let ids = (0 .. 4).toSeq.mapIt(store.push(it * 10))

    discard store.del(ids[1])
    discard store.del(ids[3])

    # The slots stick around even though the values in them do not
    check(store.wholeSpan.slots == 5)
    check(store.wholeSpan.items(int).toSeq == @[0, 20, 40])

  test "Spans report liveness by index":
    var store = newBlockStore[int](50)
    let ids = (0 .. 2).toSeq.mapIt(store.push(it))
    discard store.del(ids[1])

    let span = store.wholeSpan
    check(span.isAlive(0))
    check(not span.isAlive(1))
    check(span.isAlive(2))

  test "Deleting values a span has not reached yet":
    var store = newBlockStore[int](50)
    for i in 0 .. 9:
      discard store.push(i)

    var seen: seq[int]
    for value in store.wholeSpan.items(int):
      if value == 0:
        for idx in 5'u .. 9'u:
          discard store.del(idx)
      seen.add(value)

    check(seen == @[0, 1, 2, 3, 4])

  test "Values pushed after a span is taken are left out of it":
    var store = newBlockStore[int](50)
    for i in 0 .. 2:
      discard store.push(i)

    var seen: seq[int]
    for value in store.wholeSpan.items(int):
      discard store.push(value + 100)
      seen.add(value)

    check(seen == @[0, 1, 2])
    check(store.wholeSpan.items(int).toSeq == @[0, 1, 2, 100, 101, 102])

  test "Walking a span as the wrong type":
    var store = newBlockStore[string](10)
    discard store.push("foo")

    expect AssertionDefect:
      for value in store.wholeSpan.items(int):
        discard value

  test "Walking a span as the start of its slots":
    var store = newBlockStore[tuple[first: int32, second: int64]](10)
    discard store.push((1'i32, 2'i64))
    discard store.push((3'i32, 4'i64))

    # A slot can be walked as anything that fits in it, not just as the whole thing
    check(store.wholeSpan.addresses(int32).toSeq.mapIt(it[]) == @[1'i32, 3'i32])

  test "Walking a span as a type too big for its slots":
    var store = newBlockStore[int32](10)
    discard store.push(1'i32)

    expect AssertionDefect:
      for address in store.wholeSpan.addresses(array[4, int64]):
        discard address

  test "Spans cover recycled slots":
    var store = newBlockStore[int](50)
    let first = store.push(1)
    discard store.push(2)
    discard store.del(first)

    check(store.wholeSpan.items(int).toSeq == @[2])

    discard store.push(3)
    check(store.wholeSpan.items(int).toSeq == @[3, 2])

  test "Manual iteration":
    var store = newBlockStore[string](50)
    let id1 = store.push("foo")
    let id2 = store.push("bar")
    let id3 = store.push("baz")

    var iter: BlockIter
    check(not iter.isDone)
    check(store.next(iter)[] == "foo")
    check(not iter.isDone)
    check(store.next(iter)[] == "bar")
    check(not iter.isDone)
    check(store.next(iter)[] == "baz")
    check(not iter.isDone)
    check(store.next(iter) == nil)
    check(iter.isDone)
