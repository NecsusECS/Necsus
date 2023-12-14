import unittest, necsus

type
    A = object
    B = object

proc setup(
    spawn: Spawn[(A, )],
    attach: Attach[(B, )],
    detach: Detach[(B, )],
    delete: Delete,
    queryA: Query[(A, )],
    queryB: Query[(B, )]
) =
    check(queryA.len == 0)
    check(queryB.len == 0)

    for i in 1..5:
        spawn.with(A())

    check(queryA.len == 5)
    check(queryB.len == 0)

    for eid, _ in queryA:
        eid.attach((B(), ))

    check(queryA.len == 5)
    check(queryB.len == 5)

    for eid, _ in queryB:
        eid.detach()

    check(queryA.len == 5)
    check(queryB.len == 0)

    for eid, _ in queryA:
        eid.delete()

    check(queryA.len == 0)
    check(queryB.len == 0)

proc runner(tick: proc(): void) = tick()

proc queryLen() {.necsus(runner, [~setup], [], [], newNecsusConf()).}

test "Report the length of a query":
    queryLen()
