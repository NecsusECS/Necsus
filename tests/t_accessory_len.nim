import necsus, std/[unittest, options]

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
    people: Query[(Person, Name)],
    ages: Query[(Age, )],
    all: Query[(Person, Name, Age)],
    notAge: Query[(Person, Not[Age])],
    maybeAge: Query[(Person, Option[Age])],
) =
    check(people.len == 3)
    check(ages.len == 2)
    check(all.len == 2)
    check(notAge.len == 1)
    check(maybeAge.len == 3)

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~setup, ~assertion], conf = newNecsusConf()).}

test "Query length with accessory components":
    myApp()