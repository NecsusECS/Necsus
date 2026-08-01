import unittest, necsus, sequtils, algorithm

type Thingy = object
  number: int

proc setup(spawn: Spawn[(Thingy,)]) =
  for i in 1 .. 3:
    spawn.with(Thingy(number: i))

proc spawnMore(all: Query[(Thingy,)], spawn: Spawn[(Thingy,)]) =
  var visited: seq[int]
  for comp in all:
    visited.add(comp[0].number)
    if comp[0].number < 3:
      spawn.with(Thingy(number: comp[0].number * 100))
  check(visited.sorted == @[1, 2, 3])

proc assertions(all: Query[(Thingy,)]) =
  check(toSeq(all.items).mapIt(it[0].number).sorted == @[1, 2, 3, 100, 200])

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~setup, ~spawnMore, ~assertions], newNecsusConf()).}

test "Entities spawned during iteration are skipped":
  myApp()
