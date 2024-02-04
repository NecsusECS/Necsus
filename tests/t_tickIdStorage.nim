import unittest, necsus

proc checkTick(tickId: TickId): auto {.instanced.} =
    var stored: uint
    return proc() =
        check(tickId() != stored)
        stored = tickId()

proc runner(tick: proc(): void) =
    for i in 1..10:
        tick()

proc myApp() {.necsus(runner, [~checkTick], newNecsusConf()).}

test "Storing a TickId should store the value and not the pointer":
    myApp()

