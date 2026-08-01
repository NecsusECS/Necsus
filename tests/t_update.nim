import unittest, necsus, sequtils, algorithm

type
  Name = object
    name*: string

  Age = object
    age*: int

  Mood = object
    mood*: string

proc setup(spawn: Spawn[(Age, Mood, Name)]) =
  spawn.with(Age(age: 20), Mood(mood: "Happy"), Name(name: "Foo"))
  spawn.with(Age(age: 30), Mood(mood: "Sad"), Name(name: "Bar"))

proc modify(all: FullQuery[(Age, Mood)], attach: Attach[(Age, Mood)]) =
  for entityId, info in all:
    let newAge = Age(age: info[0].age + 1)
    let newMood = Mood(mood: "Very " & info[1].mood)
    entityId.attach((newAge, newMood))

proc assertions(all: Query[(Name, Age, Mood)]) =
  let found = toSeq(all.items).mapIt((it[0].name, it[1].age, it[2].mood)).sorted
  check(found == @[("Bar", 31, "Very Sad"), ("Foo", 21, "Very Happy")])

proc runner(tick: proc(): void) =
  tick()

proc testAttaches() {.necsus(runner, [~setup, ~modify, ~assertions], newNecsusConf()).}

test "Updating components via an Attach":
  testAttaches()
