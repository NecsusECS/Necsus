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
    fullQueryA: FullQuery[(A, )],
    queryB: Query[(B, )],
    fullQueryB: FullQuery[(B, )],
) =
    check(queryA.len == 0)
    check(fullQueryA.len == 0)
    check(queryB.len == 0)
    check(fullQueryB.len == 0)

    for i in 1..5:
        spawn.with(A())

    check(queryA.len == 5)
    check(queryB.len == 0)

    for eid, _ in fullQueryA:
        eid.attach((B(), ))

    check(queryA.len == 5)
    check(fullQueryA.len == 5)
    check(queryB.len == 5)
    check(fullQueryB.len == 5)

    for eid, _ in fullQueryB:
        eid.detach()

    check(queryA.len == 5)
    check(fullQueryA.len == 5)
    check(queryB.len == 0)
    check(fullQueryB.len == 0)

    for eid, _ in fullQueryA:
        eid.delete()

    check(queryA.len == 0)
    check(fullQueryA.len == 0)
    check(queryB.len == 0)
    check(fullQueryB.len == 0)

proc runner(tick: proc(): void) = tick()

proc queryLen() {.necsus(runner, [~setup], [], [], newNecsusConf()).}

test "Report the length of a query":
    queryLen()
