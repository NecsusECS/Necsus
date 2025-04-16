import necsus, std/[unittest, sequtils, sets]

type
  Person = object

  Name = string

  Immortal = bool

  Age {.accessory.} = int

  LostTheirMarbles = object

  Marbles {.accessory.} = int

proc setup(
    spawn: FullSpawn[(Age, LostTheirMarbles, Name, Person)],
    markImmortal: Swap[(Immortal,), (Age,)],
    giveMarbles: Swap[(Marbles,), (LostTheirMarbles,)],
) =
  discard spawn.with(41, LostTheirMarbles(), "John", Person())
  spawn.with(50, LostTheirMarbles(), "Jack", Person()).markImmortal((true,))
  spawn.with(30, LostTheirMarbles(), "Jane", Person()).giveMarbles((5,))

proc assertion(
    all: Query[(Name,)], aged: Query[(Name, Age)], marbles: Query[(Name, Marbles)]
) =
  check(toSeq(all.items).mapIt(it[0]).toHashSet == @["Jack", "John", "Jane"].toHashSet)
  check(toSeq(aged.items) == @[("Jane", 30), ("John", 41)])
  check(toSeq(marbles.items) == @[("Jane", 5)])

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~setup, ~assertion], conf = newNecsusConf()).}

test "Swapping an accessory component":
  myApp()
