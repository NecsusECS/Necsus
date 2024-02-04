import unittest, necsus, sequtils, algorithm

type All = object

proc spawn5(spawn: Spawn[(All, )]) =
    for i in 1..5:
        spawn.with(All(), )

proc assertions(all: FullQuery[(All, )]) =
    check(all.pairs.toSeq.mapIt(int(it[0])).sorted == @[0, 1, 2, 3, 4])

proc deleteAll(all: FullQuery[tuple[thingy: All]], delete: Delete) =
    for entityId, _ in all:
        delete(entityId)

proc runner(tick: proc(): void) =
    tick()
    tick()

proc myApp() {.necsus(runner, [~spawn5, ~assertions, ~deleteAll], newNecsusConf()).}

test "Reusing deleted entityIDs":
    myApp()
