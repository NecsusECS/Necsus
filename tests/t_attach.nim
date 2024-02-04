import unittest, necsus, sequtils

type
    Name = object
        name*: string
    Age = object
        age*: int
    FavoriteNumber = object
        number*: int

proc setup(spawn: Spawn[(Name, )]) =
    spawn.with(Name(name: "Foo"))
    spawn.with(Name(name: "Bar"))

proc modify(all: FullQuery[(Name, )], addAge: Attach[(Age, )], addNum: Attach[(FavoriteNumber, )]) =
    var i = 0
    for entityId, _ in all:
        i += 1
        entityId.addAge((Age(age: i + 20), ))
        entityId.addNum((FavoriteNumber(number: i), ))

proc assertions(all: Query[(Name, Age, FavoriteNumber)]) =
    check(toSeq(all.items).mapIt(it[0].name) == @["Foo", "Bar"])
    check(toSeq(all.items).mapIt(it[1].age) == @[21, 22])
    check(toSeq(all.items).mapIt(it[2].number) == @[1, 2])

proc runner(tick: proc(): void) =
    tick()

proc testAttaches() {.necsus(runner, [~setup, ~modify, ~assertions], newNecsusConf()).}

test "Attaching components":
    testAttaches()
