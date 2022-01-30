import unittest, necsus

proc runner(tick: proc(): void) =
    tick()

let initialSize = 100 + 1 * 2

proc myApp() {.necsus(runner, [], [], [], newNecsusConf(initialSize)).}

test "Loading initial size from a variable declaration":
    myApp()
