import unittest, necsus, sequtils

type
    Name = object
        name*: string
    Age = object
        age*: int
    Mood = object
        mood*: string

proc setup(spawn: Spawn[(Name, Age, Mood)]) =
    discard spawn((Name(name: "Foo"), Age(age: 20), Mood(mood: "Happy")))
    discard spawn((Name(name: "Bar"), Age(age: 30), Mood(mood: "Sad")))

proc modify(all: Query[(Age, Mood)], attach: Attach[(Age, Mood)]) =
    for entityId, info in all:
        let newAge = Age(age: info[0].age + 1)
        let newMood = Mood(mood: "Very " & info[1].mood)
        entityId.attach((newAge, newMood))

proc assertions(all: Query[(Name, Age, Mood)]) =
    check(toSeq(all.items).mapIt(it[0].name) == @["Foo", "Bar"])
    check(toSeq(all.items).mapIt(it[1].age) == @[21, 31])
    check(toSeq(all.items).mapIt(it[2].mood) == @["Very Happy", "Very Sad"])

proc runner(tick: proc(): void) =
    tick()

proc testAttaches() {.necsus(runner, [~setup], [~modify, ~assertions], [], newNecsusConf()).}

test "Attaching components":
    testAttaches()
