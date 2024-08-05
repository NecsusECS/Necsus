import necsus, std/[sequtils, unittest]

type
    Person = object

    Name = object
        name*: string

    Age {.accessory.} = object
        age*: int

proc setup(spawn: Spawn[(Age, Name, Person)], spawn2: Spawn[(Name, Person)]) =
    spawn.with(Age(age: 50), Name(name: "Jack"), Person())
    spawn.with(Age(age: 40), Name(name: "Jill"), Person())
    spawn2.with(Name(name: "John"), Person())

proc assertion(
    people: Query[tuple[person: Person, name: Name]],
    ages: Query[tuple[age: Age, ]],
    all: Query[tuple[person: Person, name: Name, age: Age]]
) =
    check(toSeq(people.items).mapIt(it.name.name) == @["Jack", "Jill", "John"])
    check(toSeq(ages.items).mapIt(it.age.age) == @[50, 40])
    check(toSeq(all.items).mapIt(it.name.name) == @["Jack", "Jill"])

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~setup, ~assertion], conf = newNecsusConf()).}


test "System with accessory components":
    myApp()