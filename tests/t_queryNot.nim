import unittest, necsus, sequtils

type
  A = object
    phase: int

  B = object
  C = object

proc setup(
    spawnAB: FullSpawn[(A, B)], spawnABC: Spawn[(A, B, C)], attachC: Attach[(C,)]
) =
  for i in 1 .. 5:
    discard spawnAB.with(A(phase: 1), B())
    spawnABC.with(A(phase: 2), B(), C())
    spawnAB.with(A(phase: 3), B()).attachC((C(),))

proc assertions(query: Query[(A, B, Not[C])]) =
  check(query.items.toSeq.mapIt(it[0].phase) == @[1, 1, 1, 1, 1])

proc runner(tick: proc(): void) =
  tick()

proc notQuery() {.necsus(runner, [~setup, ~assertions], newNecsusConf()).}

test "Exclude entities with a component":
  notQuery()
