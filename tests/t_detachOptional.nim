import unittest, necsus, sequtils, options

type
  A = char
  B = char
  C = char
  D = char
  E = char

proc setup(spawnABCD: Spawn[(A, B, C, D)], spawnABCDE: Spawn[(A, C, D, E)]) =
  spawnABCD.with('A', 'B', 'C', 'D')
  spawnABCDE.with('a', 'c', 'd', 'e')

proc detacher(query: FullQuery[(A,)], detach: Detach[(C, D, Option[E])]) =
  for entityId, _ in query:
    detach(entityId)

proc assertions(
    findA: Query[(A,)],
    findB: Query[(B,)],
    findC: Query[(C,)],
    findD: Query[(D,)],
    findE: Query[(E,)],
) =
  check(findA.toSeq() == @[('a',), ('A',)])
  check(findB.toSeq() == @[('B',)])
  check(findC.toSeq().len == 0)
  check(findD.toSeq().len == 0)
  check(findE.toSeq().len == 0)

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~setup, ~detacher, ~assertions], newNecsusConf()).}

test "Detaching optionals should remove them if present":
  myApp()
