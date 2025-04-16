import necsus, std/[sequtils, unittest]

type
  Person = object

  Name = string

  Age {.accessory.} = int

proc setup(spawn: FullSpawn[(Name, Person, Age)], detach: Detach[(Age,)]) =
  spawn.with("Jack", Person(), 50).detach()
  discard spawn.with("Jill", Person(), 60)

proc assertion(all: Query[(Name,)], aged: Query[(Name, Age)]) =
  check(toSeq(all.items) == @[("Jack",), ("Jill",)])
  check(toSeq(aged.items) == @[("Jill", 60)])

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~setup, ~assertion], conf = newNecsusConf()).}

test "Attaching an accessory component":
  myApp()
