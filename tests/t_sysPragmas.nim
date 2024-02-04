import unittest, necsus

var accum: string = "value:"

proc atStartup() {.startupSys.} =
    check(accum == "value:")
    accum &= " startup"

proc inLoop() {.loopSys.} =
    check(accum == "value: startup")
    accum &= " loop"

proc atTeardown() {.teardownSys.} =
    check(accum == "value: startup loop")
    accum &= " teardown"

proc runner(tick: proc(): void) =
    check(accum == "value: startup")
    tick()
    check(accum == "value: startup loop")

proc myApp() {.necsus(runner, [~atTeardown, ~atStartup, ~inLoop], newNecsusConf()).}

test "Explicitly defining the execution location for systems":
    myApp()
    check(accum == "value: startup loop teardown")
