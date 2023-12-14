import unittest, sequtils, necsus

type
    Person = object
    Name = object
        name*: string
    Age = object
        age*: int

proc setup1(spawn: Spawn[(Name, Person)], spawnAll: Spawn[(Age, Name, Person)]) =
    spawn.with(Name(name: "Jack"), Person())
    spawn.with(Name(name: "Jill"), Person())
    spawnAll.with(Age(age: 40), Name(name: "John"), Person())

proc setup2(spawnAge: Spawn[(Age, )], spawnPerson: Spawn[(Person, )]) =
    spawnAge.with(Age(age: 39))
    spawnPerson.with(Person())
    spawnPerson.with(Person())

proc spawnMore(spawn: Spawn[(Name, Person)]) =
    spawn.with(Name(name: "Joe"), Person())

proc assertion(
    people: Query[tuple[person: Person, name: Name]],
    ages: Query[tuple[age: Age, ]],
    all: Query[tuple[person: Person, name: Name, age: Age]]
) =
    check(toSeq(people.items).mapIt(it.name.name) == @["Jack", "Jill", "Joe", "John"])
    check(toSeq(ages.items).mapIt(it.age.age) == @[40, 39])
    check(toSeq(all.items).mapIt(it.name.name) == @["John"])

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~setup1, ~setup2], [~spawnMore], [~assertion], conf = newNecsusConf()).}

test "Basic system":
    myApp()
