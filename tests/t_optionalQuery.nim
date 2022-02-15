import unittest, necsus, sequtils, options

type
    A = object
    B = object
    C = object
        c: int
    D = object
        d: int

proc setup(spawnAB: Spawn[(A, B)], spawnABC: Spawn[(A, B, C)], attachC: Attach[(C, D)]) =
    for i in 1..3:
        discard spawnAB((A(), B()))
        discard spawnABC((A(), B(), C(c: i)))
        spawnAB((A(), B())).attachC((C(c: i + 10), D(d: i + 20)))

proc update(query: Query[(Option[ptr D], )]) =
    for (d, ) in query:
        if d.isSome:
            d.get().d += 30

proc assertions(query: Query[(A, B, Option[C], Option[D])]) =
    check(query.items.toSeq.len == 9)
    check(query.items.toSeq.filterIt(it[2].isSome).mapIt(it[2].get().c) == @[1, 11, 2, 12, 3, 13])
    check(query.items.toSeq.filterIt(it[2].isNone).len == 3)
    check(query.items.toSeq.filterIt(it[3].isSome).mapIt(it[3].get().d) == @[51, 52, 53])
    check(query.items.toSeq.filterIt(it[3].isNone).len == 6)

proc runner(tick: proc(): void) = tick()

proc optionalQuery() {.necsus(runner, [~setup], [~update], [~assertions], newNecsusConf()).}

test "Queries with optional components":
    optionalQuery()
