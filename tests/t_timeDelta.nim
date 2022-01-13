import unittest, necsus, sequtils, os

type Dummy = object

proc setup(dt: TimeDelta, spawn: Spawn[(Dummy, )]) =
    check(dt == 0)

var isFirst = true

proc checkTime(dt: TimeDelta) =
    if isFirst:
        isFirst = false
    else:
        check(dt >= 0.008)
    sleep(10)

proc runner(tick: proc(): void) =
    for i in 1..10:
        tick()

proc myApp() {.necsus(runner, [~setup], [~checkTime], initialSize = 100).}

test "Time delta tracking":
    myApp()

