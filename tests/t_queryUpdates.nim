import unittest, necsus, sequtils

type
    A = object
    B = object
    C = object
    D = object

proc setup(spawn: Spawn[(A, B)]) =
    for i in 1..5:
        spawn.with(A(), B())

proc addC(query: Query[(A, B)], attach: Attach[(C, )]) =
    for eid, comps in query:
        eid.attach((C(), ))

proc assertABC(query: Query[(A, B, C)]) =
    check(toSeq(query.items).len == 5)

proc addD(query: Query[(A, B)], attach: Attach[(D, )]) =
    for eid, comps in query:
        eid.attach((D(), ))

proc assertABCD(query: Query[(A, B, C, D)]) =
    check(toSeq(query.items).len == 5)

proc runner(tick: proc(): void) =
    tick()

proc attachQuery() {.necsus(runner, [~setup], [~addC, ~assertABC, ~addD], [~assertABCD], newNecsusConf()).}

test "Update query when new components are attached":
    attachQuery()
