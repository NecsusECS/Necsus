import unittest, sequtils, necsus

type
    Person = object
    Name = object
        name*: string
    Age = object
        age*: int

proc setup1(spawn: Spawn[(Person, Name)], spawnAll: Spawn[(Person, Name, Age)]) =
    discard spawn.with(Person(), Name(name: "Jack"))
    discard spawn.with(Person(), Name(name: "Jill"))
    discard spawnAll.with(Person(), Name(name: "John"), Age(age: 40))

proc setup2(spawnAge: Spawn[(Age, )], spawnPerson: Spawn[(Person, )]) =
    discard spawnAge.with(Age(age: 39))
    discard spawnPerson.with(Person())
    discard spawnPerson.with(Person())

proc spawnMore(spawn: Spawn[(Person, Name)]) =
    discard spawn.with(Person(), Name(name: "Joe"))

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
