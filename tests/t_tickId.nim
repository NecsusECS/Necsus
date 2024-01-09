import unittest, necsus

var expecting = 1'u

type BundledTickId = object
    tickId: TickId

proc checkTick(tickId: TickId, tickId2: TickId, tickBundle: Bundle[BundledTickId]) =
    check(tickId == expecting)
    check(tickId2 == expecting)
    check(tickBundle.tickId == expecting)
    expecting += 1

proc runner(tick: proc(): void) =
    for i in 1..10:
        tick()

proc myApp() {.necsus(runner, [], [~checkTick], [], newNecsusConf()).}

test "TickId tracking":
    myApp()
