import unittest, necsus, sequtils

type
    Person = object
    Name = object
        name*: string
    Age = object
        age*: int

proc setup1(spawn: Spawn[(Person, Name)]) =
    discard spawn((Person(), Name(name: "Jack")))
    discard spawn((Person(), Name(name: "Jill")))

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
    echo "starting assertion"

    check(toSeq(people.components).mapIt(it.name.name) == @["Jack", "Jill", "Joe"])
    check(toSeq(ages.components).mapIt(it.age.age) == @[39])
    check(toSeq(all.components).len == 0)

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~setup1, ~setup2], [~spawnMore], [~assertion], conf = newNecsusConf()).}

test "Basic system":
    myApp()
