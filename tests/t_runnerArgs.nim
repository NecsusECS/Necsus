import unittest, necsus, sequtils, options

type
    A = object
        value: int
    B = object
    C = object
    D = object
    E = object
        value: int

proc setup(
    sharedVar: var Shared[string],
    spawn: Spawn[(B, D, E)],
) =
    sharedVar.set("foo")
    discard spawn((B(), D(), E(value: 789)))

proc runner(
    time: TimeDelta,
    sharedVar: Shared[string],
    spawn: Spawn[(A, )],
    query: Query[(B, )],
    attach: Attach[(C, )],
    detachD: Detach[(D, )],
    lookup: Lookup[(E, )],
    tick: proc(): void
) =
    check(sharedVar.get() == "foo")
    discard spawn((A(value: 123), ))

    check(query.components.toSeq.len == 1)

    for (eid, comp) in query:
        eid.attach((C(), ))
        eid.detachD()
        check(eid.lookup().get()[0].value == 789)

    tick()

proc assertions(checkA: Query[(A, )], checkBC: Query[(B, C)], checkD: Query[(D, )]) =
    check(checkA.components.toSeq.mapIt(it[0].value) == @[123])
    check(checkBC.components.toSeq.len == 1)
    check(checkD.components.toSeq.len == 0)

proc testRunnerArgs() {.necsus(runner, [~setup], [~assertions], [], newNecsusConf()).}

test "Passing directives into the runner":
    testRunnerArgs()
