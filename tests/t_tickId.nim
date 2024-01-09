import unittest, necsus

var expecting = 1'u

proc checkTick(tickId: TickId, tickId2: TickId) =
    check(tickId == expecting)
    check(tickId2 == expecting)
    expecting += 1

proc runner(tick: proc(): void) =
    for i in 1..10:
        tick()

proc myApp() {.necsus(runner, [], [~checkTick], [], newNecsusConf()).}

test "TickId tracking":
    myApp()
