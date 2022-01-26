import unittest, necsus, strformat

type Dummy = object

proc runner(tick: proc(): void) = tick()

proc run(initialSize: int) =

    proc system(spawn: Spawn[(Dummy, )]) =
        for i in 1..initialSize:
            discard spawn((Dummy(), ))

    proc myApp() {.necsus(runner, [], [~system], newNecsusConf(initialSize, initialSize)).}

    test &"World with {initialSize} entities":
        myApp()

suite "Many entities":
    run(100_000)
    run(1_000_000)
