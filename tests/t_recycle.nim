import unittest, necsus, sequtils, times, algorithm

type All = object

proc spawn5(spawn: Spawn[(All, )]) =
    for i in 1..5:
        discard spawn((All(), ))

proc deleteAll(all: Query[tuple[thingy: All]], delete: Delete) =
    for (entityId, _) in all.pairs:
        delete(entityId)

proc assertions(all: Query[(All, )]) =
    check(all.pairs.toSeq.mapIt(int(it[0])).sorted == @[0, 1, 2, 3, 4])

proc runner(tick: proc(): void) =
    tick()
    tick()

proc myApp() {.necsus(runner, [], [~spawn5, ~assertions, ~deleteAll], initialSize = 100).}

test "Deleting entities":
    myApp()




