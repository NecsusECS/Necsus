import unittest, necsus, sets

type Widget[T] = object

template create(T: typedesc): untyped =
    proc doSetup(spawn: Spawn[(Widget[T], )]) =
        spawn.with(Widget[T]())

    proc assertions(people: Query[(ptr Widget[T], )],) =
        check(people.len == 1)

create(string)

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~doSetup, ~assertions], conf = newNecsusConf()).}

test "Parsing systems with open symbols":
    myApp()

