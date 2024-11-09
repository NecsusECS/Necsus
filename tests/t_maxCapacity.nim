import unittest, necsus

let WRAP_CAPACITY: uint8 = 5

type
    A {.maxCapacity(2).} = object
    B = A
    Wrap[T] {.maxCapacity(WRAP_CAPACITY).} = object

proc spawnToLimit[C: tuple](spawn: Spawn[C], count: auto, value: C) =
    for _ in 0..<count:
        necsus.set(spawn, value)
    expect IndexDefect:
        necsus.set(spawn, value)

proc setup(
    spawn1: Spawn[(A, string)],
    spawn2: Spawn[(B, string)],
    spawn3: Spawn[(string, Wrap[A])],
    spawn4: Spawn[(A, Wrap[string])],
) =
    spawn1.spawnToLimit(2, (A(), "foo"))
    spawn2.spawnToLimit(2, (B(), "foo"))
    spawn3.spawnToLimit(5, ("foo", Wrap[A]()))
    spawn4.spawnToLimit(5, (A(), Wrap[string]()))

proc assertion(
    query1: Query[(A, string)],
    query2: Query[(B, string)],
    query3: Query[(string, Wrap[A])],
    query4: Query[(A, Wrap[string])],
) =
    check(query1.len == 2)
    check(query2.len == 2)
    check(query3.len == 5)
    check(query4.len == 5)

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~setup, ~assertion], conf = newNecsusConf()).}

test "Components with a max capacity":
    myApp()
