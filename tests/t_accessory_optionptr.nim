import necsus, std/[sequtils, unittest, options]

type
  Name = string

  Age {.accessory.} = object
    age: int

proc setup(spawn: FullSpawn[(Age, Name)], getAge: Lookup[(Option[ptr Age],)]) =
  spawn.with(Age(age: 41), "Jack").getAge().get()[0].get().age += 1

proc assertion(all: Query[(Name, Age)]) =
  check(toSeq(all.items).mapIt(it[1].age) == @[42])

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~setup, ~assertion], conf = newNecsusConf()).}

test "Optional lookup with a pointer to an accessory":
  myApp()
