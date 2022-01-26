import unittest, necsus

type Dummy = object

proc system(spawn: Spawn[(Dummy, )]) =
    discard

proc runner(tick: proc(): void) =
    tick()

let initialSize = 100 + 1 * 2

proc myApp() {.necsus(runner, [], [~system], newNecsusConf(initialSize)).}

test "Loading initial size from a variable declaration":
    myApp()
