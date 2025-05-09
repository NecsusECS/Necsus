import unittest, necsus, sequtils

type Thingy = object
  number: int

proc setup(spawn: Spawn[(Thingy,)]) =
  for i in 1 .. 10:
    spawn.with(Thingy(number: i))

proc rm(all: FullQuery[tuple[thingy: Thingy]], delete: Delete) =
  for entityId, info in all:
    if info.thingy.number mod 2 == 0:
      delete(entityId)

proc assertions(all: Query[(Thingy,)]) =
  check(toSeq(all.items).mapIt(it[0].number) == @[1, 3, 5, 7, 9])

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~setup, ~rm, ~assertions], newNecsusConf()).}

test "Deleting entities":
  myApp()
