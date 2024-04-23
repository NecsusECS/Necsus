import unittest, necsus, std/options

type
    A = int
    B = int
    C = int
    D = int

    BaseTuple = (A, C)

proc spawner(spawn: Spawn[extend(BaseTuple, (B, D))]) =
    spawn.with(1, 2, 3, 4)

proc checker(query: Query[extend(BaseTuple, (B, D))]) =
    let values: (A, B, C, D) = query.single.get
    check(values[0] == 1)
    check(values[1] == 2)
    check(values[2] == 3)
    check(values[3] == 4)

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [~spawner, ~checker], newNecsusConf()).}

test "Extending a base tuple should create a usable new tuple":
    myApp()
