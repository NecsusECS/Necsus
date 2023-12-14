import unittest, necsus

type Dummy = object

proc runner(tick: proc(): void) = tick()

proc buildSystem(size: int): auto =
    return proc(spawn: Spawn[(Dummy, )]) =
        for i in 1..size:
            spawn.with(Dummy())

let system100k = buildSystem(100_000)
proc hudrendThousand() {.necsus(runner, [], [~system100k], [], newNecsusConf(100_000, 100_000)).}

let system1M = buildSystem(1_000_000)
proc million() {.necsus(runner, [], [~system1M], [], newNecsusConf(1_000_000, 1_000_000)).}

test "World with 100_000 entities":
    hudrendThousand()

test "World with 1_000_000 entities":
    million()
