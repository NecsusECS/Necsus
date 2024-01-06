import unittest, necsus, sequtils, options, sets

type
    A = object
    B = object
    C = object
        c: int
    D = object
        d: int

proc setup(spawnAB: FullSpawn[(A, B)], spawnABC: Spawn[(A, B, C)], attachC: Attach[(C, D)]) =
    for i in 1..3:
        discard spawnAB.with(A(), B())
        spawnABC.with(A(), B(), C(c: i))
        spawnAB.with(A(), B()).attachC((C(c: i + 10), D(d: i + 20)))

proc update(query: Query[(Option[ptr D], )]) =
    for (d, ) in query:
        if d.isSome:
            d.get().d += 30

proc assertions(query: Query[(A, B, Option[C], Option[D])]) =
    check(query.items.toSeq.len == 9)
    check(query.items.toSeq.filterIt(it[2].isSome).mapIt(it[2].get().c).toHashSet == [1, 11, 2, 12, 3, 13].toHashSet)
    check(query.items.toSeq.filterIt(it[2].isNone).len == 3)
    check(query.items.toSeq.filterIt(it[3].isSome).mapIt(it[3].get().d).toHashSet == [51, 52, 53].toHashSet)
    check(query.items.toSeq.filterIt(it[3].isNone).len == 6)

proc runner(tick: proc(): void) = tick()

proc optionalQuery() {.necsus(runner, [~setup], [~update], [~assertions], newNecsusConf()).}

test "Queries with optional components":
    optionalQuery()
