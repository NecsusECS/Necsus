import unittest, necsus

type
    Thingy = int

    Excluded = object

proc setup(spawn: Spawn[(Thingy, )], spawn2: Spawn[(Thingy, Excluded)]) =
    for i in 1..10:
        spawn.with(i, )

    for i in 1..10:
        spawn2.with(i, Excluded())

proc rm(del: DeleteAll[(Thingy, Not[Excluded])]) =
    del()

proc assertions(all: Query[(Thingy, )]) =
    check(all.len == 10)

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [~setup, ~rm, ~assertions], newNecsusConf()).}

test "Deleting all entities":
    myApp()

