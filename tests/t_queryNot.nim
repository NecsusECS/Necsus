import unittest, necsus, sequtils

type
    A = object
    B = object
    C = object

proc setup(spawnAB: Spawn[(A, B)], spawnABC: Spawn[(A, B, C)], attachC: Attach[(C, )]) =
    for i in 1..5:
        discard spawnAB((A(), B()))
        discard spawnABC((A(), B(), C()))
        spawnAB((A(), B())).attachC((C(), ))

proc assertions(query: Query[(A, B, Not[C])]) =
    check(toSeq(query.items).len == 5)

proc runner(tick: proc(): void) = tick()

proc notQuery() {.necsus(runner, [~setup], [], [~assertions], newNecsusConf()).}

test "Exclude entities with a component":
    notQuery()
