import necsus, std/[sequtils, sets, unittest]

type
  Person = object

  Name = string

  Age {.accessory.} = int

  Marbles {.accessory.} = int

  Arms = int

proc setup(
    spawn1: Spawn[(Age, Name, Person)],
    spawn2: Spawn[(Marbles, Name, Person)],
    spawn3: Spawn[(Arms, Name, Person)],
) =
  spawn1.with(100, "Jack", Person())
  spawn2.with(41, "Jill", Person())
  spawn3.with(2, "John", Person())

proc assertion(
    all: Query[(Name,)],
    notAged: Query[(Name, Not[Age])],
    noMarbles: Query[(Name, Not[Marbles])],
    marblesNoAge: Query[(Marbles, Not[Age])],
    ageNoMarbles: Query[(Age, Not[Marbles])],
) =
  check(toSeq(all.items).toHashSet == @[("John",), ("Jack",), ("Jill",)].toHashSet)
  check(toSeq(notAged.items).mapIt(it[0]).toHashSet == @["John", "Jill"].toHashSet)
  check(toSeq(noMarbles.items).mapIt(it[0]).toHashSet == @["John", "Jack"].toHashSet)
  check(toSeq(marblesNoAge.items).mapIt(it[0]) == @[41])
  check(toSeq(ageNoMarbles.items).mapIt(it[0]) == @[100])

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~setup, ~assertion], conf = newNecsusConf()).}

test "Using a 'Not' query on accessory components":
  myApp()
