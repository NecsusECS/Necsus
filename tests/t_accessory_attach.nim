import necsus, std/[sequtils, unittest]

type
  Person = object

  Name = string

  Age {.accessory.} = int

proc setup(spawn: FullSpawn[(Name, Person)], add: Attach[(Age,)]) =
  spawn.with("Jack", Person()).add((50,))

proc assertion(all: Query[tuple[name: Name, age: Age]]) =
  check(toSeq(all.items) == @[("Jack", 50)])

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~setup, ~assertion], conf = newNecsusConf()).}

test "Attaching an accessory component":
  myApp()
