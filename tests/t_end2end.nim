import unittest

import necsus

type
    Person = object
    Name = object
        name*: string
    Age = object
        age*: int

proc setupSystem(spawn1: var Spawn[(Person, Name)], spawn2: var Spawn[(Age, )]) =
    echo "Spawned: ", spawn1.spawn((Person(), Name(name: "Jack")))
    echo "Spawned: ", spawn1.spawn((Person(), Name(name: "Jill")))
    echo "Spawned: ", spawn2.spawn((Age(age: 39), ))

proc mySystem(
    people: Query[(Person, Name)],
    ages: Query[(Age, )]
) =
    echo "starting mySystem"
    for (person, name) in people:
        echo "Person ", person, " named ", name.name

    for (age, ) in ages:
        echo "age ", age.age


# === Generated code

type
    MyAppComponents {.pure.} = enum Person, Name, Age

    PersonNameQuery = object

    MyAppComponentData = object
        person: seq[Person]
        name: seq[Name]
        age: seq[Age]

proc spawn(
    world: var World[MyAppComponents, MyAppComponentData],
    components: sink (Person, Name)
): EntityId =
    result = world.createEntity()
    associateComponent(world, result, MyAppComponents.Person,
            world.components.person, components[0])
    associateComponent(world, result, MyAppComponents.Name,
            world.components.name, components[1])

proc spawn(
    world: var World[MyAppComponents, MyAppComponentData],
    components: sink (Age, )
): EntityId =
    result = world.createEntity()
    associateComponent(world, result, MyAppComponents.Age,
            world.components.age, components[0])

proc myApp[initialSize: static int]() =

    var world = World[MyAppComponents, MyAppComponentData](
        entities: newSeq[EntityMetadata[MyAppComponents]](initialSize),
        components: MyAppComponentData(
            person: newSeq[Person](initialSize),
            name: newSeq[Name](initialSize),
            age: newSeq[Age](initialSize),
        )
    )

    let personNameQuery = newQuery(
        proc (entityId: EntityId): auto =
        (world.components.person[entityId], world.components.name[entityId])
    )

    let ageQuery = newQuery(
        proc (entityId: EntityId): auto = (world.components.age[entityId], )
    )

    setupSystem(world, world)

    mySystem(personNameQuery, ageQuery)


# === End generated code

test "Basic system":
    myApp[100]()

