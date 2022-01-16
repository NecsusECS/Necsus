import unittest, necsus

proc someSystem() =
    discard

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [], [~someSystem], initialSize = 100).}

test "Creating a world without components":
    myApp()

