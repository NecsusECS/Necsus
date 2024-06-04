import unittest, necsus, std/options

type
    A = int
    B = string
    C = float
    D = bool

    BaseTuple = (A, C)

proc spawner(spawn: Spawn[extend(BaseTuple, (B, D))]) =
    spawn.set(join((1, 3.14) as BaseTuple, ("bar", true) as (B, D)))

proc checker(query: Query[extend(BaseTuple, (B, D))]) =
    check(query.single.get == (1, "bar", 3.14, true))

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [~spawner, ~checker], newNecsusConf()).}

test "Extending a base tuple should create a usable new tuple":
    myApp()
