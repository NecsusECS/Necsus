import unittest, necsus, sequtils

type
    A = object
    B = object
    C = object
    D = object

proc setup(spawn: Spawn[(A, B)]) =
    for i in 1..5:
        discard spawn((A(), B()))

proc addC(query: Query[(A, B)], update: Update[(C, )]) =
    for (eid, comps) in query:
        eid.update((C(), ))

proc assertABC(query: Query[(A, B, C)]) =
    check(toSeq(query.components).len == 5)

proc addD(query: Query[(A, B)], update: Update[(D, )]) =
    for (eid, comps) in query:
        eid.update((D(), ))

proc assertABCD(query: Query[(A, B, C, D)]) =
    check(toSeq(query.components).len == 5)

proc runner(tick: proc(): void) =
    tick()

proc updateQuery() {.necsus(runner, [~setup], [~addC, ~assertABC, ~addD, ~assertABCD], conf = newNecsusConf()).}

test "Update query when new entities are added":
    updateQuery()
