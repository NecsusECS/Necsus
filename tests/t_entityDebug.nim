import unittest, necsus

type
    Thingy = object
        number: int

    Whatsit = string


proc spawner(spawn: Spawn[(Thingy, Whatsit)]) =
    discard spawn.with(Thingy(number: 123), "blah")

proc dump(query: Query[(Thingy, )], dump: EntityDebug) =
    for eid, _ in query:
        check(dump(eid) == "EntityId(0) = thingy_whatsit((number: 123), \"blah\")")

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [], [~spawner, ~dump], [], newNecsusConf()).}

test "Debugging entities":
    myApp()

