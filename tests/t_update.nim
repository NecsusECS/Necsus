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

proc modify(all: Query[(Age, Mood)], update: Update[(Age, Mood)]) =
    echo "starting modify"
    for (entityId, info) in all.pairs:
        entityId.update((Age(age: 50), Mood(mood: "Angry")))

proc assertions(all: Query[(Name, Age, Mood)]) =
    echo "starting assertions"
    check(toSeq(all).mapIt(it[0].name) == @["Foo", "Bar"])
    check(toSeq(all).mapIt(it[1].age) == @[50, 50])
    check(toSeq(all).mapIt(it[2].mood) == @["Angry", "Angry"])

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~setup], [~modify, ~assertions]).}

test "Updating entities":
    myApp()


