import necsus, std/[sequtils, unittest]

type
    Person = object

    Name = string

    Age {.accessory.} = int

    Marbles {.accessory.} = int

proc setup(spawn: FullSpawn[(Name, Person, Age)], change: Swap[(Marbles, ), (Age, )]) =
    spawn.with("Jack", Person(), 50).change((19, ))
    discard spawn.with("Jill", Person(), 60)

proc assertion(all: Query[(Name, )], aged: Query[(Name, Age)], marbles: Query[(Name, Marbles)]) =
    check(toSeq(all.items) == @[("Jack", ), ("Jill", )])
    check(toSeq(aged.items) == @[("Jill", 60)])
    check(toSeq(marbles.items) == @[("Jack", 19)])

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~setup, ~assertion], conf = newNecsusConf()).}

test "Swapping an accessory component":
    myApp()