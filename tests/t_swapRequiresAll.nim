import unittest, necsus, sequtils

type
    A = int
    B = int
    C = int
    D = int

proc setup(spawnNoD: Spawn[(A, B)], spawnWithD: Spawn[(A, B, D)]) =
    spawnNoD.with(1 , 10)
    spawnWithD.with(2, 20, 2000)

proc swapper(values: FullQuery[tuple[a: A]], swap: Swap[(C, ), (B, D)]) =
    for eid, comps in values:
        eid.swap((comps.a * 100, ))

proc assertSwapped(abc: Query[(A, B, C)], ab: Query[(A, B)], ac: Query[(A, C)], acd: Query[(A, C, D)]) =
    check(toSeq(abc.items).len == 0)
    check(toSeq(acd.items).len == 0)

    check(toSeq(ab.items) == @[(1, 10)])
    check(toSeq(ac.items) == @[(2, 200)])

proc runner(tick: proc(): void) =
    tick()

proc testswap() {.necsus(runner, [~setup, ~swapper, ~assertSwapped], newNecsusConf()).}

test "Swapping components":
    testswap()
