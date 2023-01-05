import unittest, sequtils, necsus
import std/[math, times], necsus/runtime/[world, archetypeStore]

type
    Person = object
    Name = object
        name*: string
    Age = object
        age*: int

proc setup1(spawn: Spawn[(Person, Name)], spawnAll: Spawn[(Person, Name, Age)]) =
    discard spawn((Person(), Name(name: "Jack")))
    discard spawn((Person(), Name(name: "Jill")))
    discard spawnAll((Person(), Name(name: "John"), Age(age: 40)))

proc setup2(spawnAge: Spawn[(Age, )], spawnPerson: Spawn[(Person, )]) =
    discard spawnAge((Age(age: 39), ))
    discard spawnPerson((Person(), ))
    discard spawnPerson((Person(), ))

proc spawnMore(spawn: Spawn[(Person, Name)]) =
    discard spawn((Person(), Name(name: "Joe")))

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
