import unittest, necsus, sequtils, intsets, std/threadpool
{.experimental: "parallel".}

type
    Num = object
        value*: int

proc exec(i: int, create: Spawn[(Num, )]) =
    discard create((Num(value: i), ))

proc setup(create: Spawn[(Num, )]) =
    parallel:
        for i in 0..5_000:
            spawn exec(i, create)

proc assertion(numbers: Query[tuple[number: Num]]) =
    let found = numbers.items.toSeq.mapIt(it.number.value).toIntSet
    let expect = (0..5_000).toSeq.toIntSet

    check((expect - found).toSeq == newSeq[int](0))
    check((found - expect).toSeq == newSeq[int](0))
    check(found.len == expect.len)

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [~setup], [], [~assertion], conf = newNecsusConf()).}

for i in 1..10:
    test "parallel spawn #" & $i:
        myApp()
