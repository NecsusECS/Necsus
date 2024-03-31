import unittest, necsus, sequtils, options

type
    A = int
    B = int
    C = int
    D = int

proc setup(spawnNoD: Spawn[(A, B)], spawnWithD: Spawn[(A, B, D)]) =
    spawnNoD.with(1 , 10)
    spawnWithD.with(2, 20, 2000)

proc swapper(values: FullQuery[(A, )], swap: Swap[(C, ), (B, Option[D])]) =
    for eid, (a, ) in values:
        eid.swap((a * 100, ))

proc assertSwapped(abc: Query[(A, B, C)], ab: Query[(A, B)], ac: Query[(A, C)], acd: Query[(A, C, D)]) =
    check(toSeq(abc.items).len == 0)
    check(toSeq(ab.items).len == 0)
    check(toSeq(ac.items) == @[(2, 200), (1, 100)])
    check(toSeq(acd.items).len == 0)

proc runner(tick: proc(): void) =
    tick()

proc testswap() {.necsus(runner, [~setup, ~swapper, ~assertSwapped], newNecsusConf()).}

test "Swapping components with optional detachments":
    testswap()
