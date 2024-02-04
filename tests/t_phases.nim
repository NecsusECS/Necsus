import unittest, necsus

var ranSetup = 0
var ranTick = 0
var ranTeardown = 0

proc setup() {.startupSys.} =
    ranSetup += 1

proc tick() =
    ranTick += 1

proc teardown() {.teardownSys.} =
    ranTeardown += 1

proc runner(tick: proc(): void) =
    tick()
    tick()
    tick()
    tick()

proc myApp() {.necsus(runner, [~setup, ~tick, ~teardown], conf = newNecsusConf()).}

test "System phases should be executed":
    myApp()
    check(ranSetup == 1)
    check(ranTick == 4)
    check(ranTeardown == 1)