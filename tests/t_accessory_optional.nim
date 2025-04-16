import necsus, std/[sequtils, unittest, options]

type
  Person = object

  Name = string

  Age {.accessory.} = int

  Marbles {.accessory.} = int

proc setup(spawn1: Spawn[(Age, Name, Person)], spawn2: Spawn[(Marbles, Name, Person)]) =
  spawn1.with(100, "Jack", Person())
  spawn2.with(41, "Jill", Person())

proc assertion(all: Query[(Name, Option[Age], Option[Marbles])]) =
  check(
    toSeq(all.items) ==
      @[("Jack", some(100), none(Marbles)), ("Jill", none(Age), some(41))]
  )

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~setup, ~assertion], conf = newNecsusConf()).}

test "Using an 'Optional' query on accessory components":
  myApp()
