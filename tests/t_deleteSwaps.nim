import unittest, necsus, std/[sequtils, options, algorithm]

type Thingy = object
  number: int

proc setup(spawn: FullSpawn[(Thingy,)], shared: Shared[seq[EntityId]]) =
  shared := toSeq(1 .. 5).mapIt(spawn.with(Thingy(number: it)))

proc removeMiddle(shared: Shared[seq[EntityId]], delete: Delete) =
  delete(shared.get[1])

proc assertions(
    all: Query[(Thingy,)], shared: Shared[seq[EntityId]], lookup: Lookup[(Thingy,)]
) =
  check(toSeq(all.items).mapIt(it[0].number).sorted() == @[1, 3, 4, 5])

  for i, eid in shared.get:
    let found = lookup(eid)
    if i == 1:
      check(found.isNone)
    else:
      check(found.isSome)
      check(found.get[0].number == i + 1)

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~setup, ~removeMiddle, ~assertions], newNecsusConf()).}

test "Deleting from the middle of an archetype":
  myApp()
