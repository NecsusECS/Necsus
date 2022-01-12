import unittest, necsus, sequtils

type
    Person = object
    Name = object
        name*: string
    Age = object
        age*: int

proc setupSystem(
    spawn1: Spawn[(Person, Name)],
    spawn2: Spawn[(Age, )],
    spawn3: Spawn[(Person, )]
) =
    discard spawn1((Person(), Name(name: "Jack")))
    discard spawn1((Person(), Name(name: "Jill")))
    discard spawn2((Age(age: 39), ))
    discard spawn3((Person(), ))
    discard spawn3((Person(), ))

proc mySystem(
    people: Query[(Person, Name)],
    ages: Query[(Age, )],
    all: Query[(Person, Name, Age)]
) =
    echo "starting mySystem"

    check(toSeq(people).mapIt(it[1].name) == @["Jack", "Jill"])
    check(toSeq(ages).mapIt(it[0].age) == @[39])
    check(toSeq(all).len == 0)

proc runner(tick: proc(): void) =
    tick()

necsus(
    name = myApp,
    runner = runner,
    startupSystems = [setupSystem],
    systems = [mySystem]
)

#test "Basic system":
#    myApp()

