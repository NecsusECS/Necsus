import necsus, std/[sequtils, unittest, sets]

type
  Name = string
  Age {.byref, used, accessory.} = int

proc setup(spawn1: Spawn[(Age, Name)], spawn2: Spawn[(Name,)]) =
  spawn1.with(41, "Jack")
  spawn2.with("Jill")

proc assertion(people: Query[(Name,)], ages: Query[(Name, Age)]) =
  check(toSeq(people.items).toHashSet == [("Jack",), ("Jill",)].toHashSet)
  check(toSeq(ages.items) == @[("Jack", 41)])

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~setup, ~assertion], conf = newNecsusConf()).}

test "System with accessory pragmas alongside other pragmas":
  myApp()
