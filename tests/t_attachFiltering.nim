import unittest, necsus, sequtils

type
    Name = object
        name*: string
    Age = object
        age*: int
    FavoriteNumber = object
        number*: int

proc setup(spawn: Spawn[(Name, )], number: Spawn[(FavoriteNumber, )]) =
    spawn.with(Name(name: "Foo"))

proc modify(all: FullQuery[(Name, )], addAge: Attach[(Age, )]) =
    for entityId, _ in all:
        entityId.addAge((Age(age: 20), ))

proc assertions(all: Query[(Name, Age)]) =
    check(toSeq(all.items).mapIt(it[0].name) == @["Foo"])
    check(toSeq(all.items).mapIt(it[1].age) == @[20])

proc runner(tick: proc(): void) =
    tick()

proc testAttaches() {.necsus(runner, [~setup], [~modify, ~assertions], [], newNecsusConf()).}

test "Attaching components":
    testAttaches()
