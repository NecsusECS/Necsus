import necsus, std/[unittest, options]

type
    Person = object

    Name {.accessory.} = string

    Age {.accessory.} = int

proc exec(
    spawn1: FullSpawn[(Person, )],
    spawn2: FullSpawn[(Person, Name)],
    spawn3: FullSpawn[(Person, Name, Age)],
    lookup1: Lookup[(Name, Not[Age])],
    lookup2: Lookup[(Name, Age)],
    lookup3: Lookup[(Name, Option[ptr Age])],
) =
    let first = spawn1.with(Person())
    check(first.lookup1().isNone())
    check(first.lookup2().isNone())
    check(first.lookup3().isNone())

    let second = spawn2.with(Person(), "Jack")
    check(second.lookup1().get()[0] == "Jack")
    check(second.lookup2().isNone())
    check(second.lookup3().isNone())

    let third = spawn3.with(Person(), "Jack", 25)
    check(third.lookup1().isNone())
    check(third.lookup2() == some(("Jack", 25)))
    check(third.lookup3().isSome())

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [~exec], conf = newNecsusConf()).}

test "Looking up an entity with an accessory":
    myApp()