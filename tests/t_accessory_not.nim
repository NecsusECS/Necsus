import necsus, std/[sequtils, unittest]

type
    Person = object

    Name = string

    Age {.accessory.} = int

    Marbles {.accessory.} = int

proc setup(spawn1: Spawn[(Age, Name, Person)], spawn2: Spawn[(Marbles, Name, Person)]) =
    spawn1.with(100, "Jack", Person())
    spawn2.with(41, "Jill", Person())

proc assertion(all: Query[(Name, )], notAged: Query[(Name, Not[Age])], noMarbles: Query[(Name, Not[Marbles])]) =
    check(toSeq(all.items) == @[("Jack", ), ("Jill", )])
    check(toSeq(notAged.items).mapIt(it[0]) == @["Jill"])
    check(toSeq(noMarbles.items).mapIt(it[0]) == @["Jack"])

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~setup, ~assertion], conf = newNecsusConf()).}

test "Using a 'Not' query on accessory components":
    myApp()
