import necsus, std/[sequtils, unittest]

type
  Name = string
  Age = int

proc setup1(spawn: Spawn[(Age, Name)]) =
  spawn.with(50, "Jack")

proc setup2(spawn1: Spawn[(Age, Name)], spawn2: FullSpawn[(Age, Name)]) =
  spawn1.with(51, "Jill")
  discard spawn2.with(53, "Joe")

proc assertion(people: Query[(Name, Age)]) =
  check(toSeq(people.items) == @[("Jack", 50), ("Jill", 51), ("Joe", 53)])

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~setup1, ~setup2, ~assertion], conf = newNecsusConf()).}

test "Same spawn appearing multiple times":
  myApp()
