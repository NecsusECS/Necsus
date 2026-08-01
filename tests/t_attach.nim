import unittest, necsus, sequtils, algorithm

type
  Name = object
    name*: string

  Age = object
    age*: int

  FavoriteNumber = object
    number*: int

proc setup(spawn: Spawn[(Name,)]) =
  spawn.with(Name(name: "Foo"))
  spawn.with(Name(name: "Bar"))

proc modify(
    all: FullQuery[(Name,)], addAge: Attach[(Age,)], addNum: Attach[(FavoriteNumber,)]
) =
  var i = 0
  for entityId, _ in all:
    i += 1
    entityId.addAge((Age(age: i + 20),))
    entityId.addNum((FavoriteNumber(number: i),))

proc assertions(all: Query[(Name, Age, FavoriteNumber)]) =
  let found = toSeq(all.items)
  check(found.mapIt(it[0].name).sorted == @["Bar", "Foo"])
  check(found.mapIt(it[2].number).sorted == @[1, 2])
  check(found.allIt(it[1].age == it[2].number + 20))

proc runner(tick: proc(): void) =
  tick()

proc testAttaches() {.necsus(runner, [~setup, ~modify, ~assertions], newNecsusConf()).}

test "Attaching components":
  testAttaches()
