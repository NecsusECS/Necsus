import unittest, necsus

type
    Thingy = object
        number: int

    Whatsit = string

proc spawner(spawn: Spawn[(Thingy, Whatsit)]) =
    spawn.with(Thingy(number: 123), "blah")

proc dump(query: FullQuery[(Thingy, )], dump: EntityDebug) =
    for eid, _ in query:
        check(dump(eid) == "EntityId(0) = Thingy_Whatsit (archetypeId0000); Thingy = (number: 123); Whatsit = blah")

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [~spawner, ~dump], newNecsusConf()).}

test "Debugging entities":
    myApp()
