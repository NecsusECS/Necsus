import unittest, necsus, os

proc setup(time: TimeElapsed) {.startupSys.} =
    check(time == 0)

var lastTimeCheck = 0.0

proc checkTime(elapsed: TimeElapsed) =
    if lastTimeCheck < 0:
        check(elapsed == 0)
    else:
        check(elapsed > lastTimeCheck)
        check(elapsed < lastTimeCheck + 100)
    lastTimeCheck = elapsed
    sleep(10)

proc runner(tick: proc(): void) =
    for i in 1..10:
        tick()

proc myApp() {.necsus(runner, [~setup, ~checkTime], newNecsusConf()).}

test "Time elapsed tracking":
    myApp()
