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


# === Generated code

type
    MyAppComponents {.pure.} = enum Person, Name, Age

    MyAppComponentData = object
        person: seq[Person]
        name: seq[Name]
        age: seq[Age]

    MyAppQueries = object
        personName: QueryMembers[MyAppComponents]
        age: QueryMembers[MyAppComponents]
        personNameAge: QueryMembers[MyAppComponents]

proc myApp[initialSize: static int]() =

    var world = World[MyAppComponents, MyAppComponentData, MyAppQueries](
        entities: newSeq[EntityMetadata[MyAppComponents]](initialSize),
        components: MyAppComponentData(
            person: newSeq[Person](initialSize),
            name: newSeq[Name](initialSize),
            age: newSeq[Age](initialSize),
        ),
        queries: MyAppQueries(
            personName: newQueryMembers[MyAppComponents](
                filterMatching({MyAppComponents.Person, MyAppComponents.Name})),
            age: newQueryMembers[MyAppComponents](
                filterMatching({MyAppComponents.Age})),
            personNameAge: newQueryMembers[MyAppComponents](
                filterMatching({MyAppComponents.Person, MyAppComponents.Name,
                        MyAppComponents.Age})),
        )
    )

    let personNameQuery = newQuery[MyAppComponents, (Person, Name)](
        world.queries.personName,
        proc (entityId: EntityId): auto = (
            world.components.person[entityId],
            world.components.name[entityId]
        )
    )

    let ageQuery = newQuery[MyAppComponents, (Age, )](
        world.queries.age,
        proc (entityId: EntityId): auto = (
            world.components.age[entityId],
        )
    )

    let personNameAgeQuery = newQuery[MyAppComponents, (Person, Name, Age)](
        world.queries.personNameAge,
        proc (entityId: EntityId): auto = (
            world.components.person[entityId],
            world.components.name[entityId],
            world.components.age[entityId]
        )
    )

    proc spawnPersonName(components: sink (Person, Name)): EntityId =
        result = world.createEntity()
        associateComponent(world, result, MyAppComponents.Person,
                world.components.person, components[0])
        associateComponent(world, result, MyAppComponents.Name,
                world.components.name, components[1])
        evaluateEntityForQuery(world, result, world.queries.personName, "personName")
        evaluateEntityForQuery(world, result, world.queries.personNameAge, "personNameAge")

    proc spawnAge(components: sink (Age, )): EntityId =
        result = world.createEntity()
        associateComponent(world, result, MyAppComponents.Age,
                world.components.age, components[0])
        evaluateEntityForQuery(world, result, world.queries.age, "age")
        evaluateEntityForQuery(world, result, world.queries.personNameAge, "personNameAge")

    proc spawnPerson(components: sink (Person, )): EntityId =
        result = world.createEntity()
        associateComponent(world, result, MyAppComponents.Person,
                world.components.person, components[0])
        evaluateEntityForQuery(world, result, world.queries.personName, "personName")
        evaluateEntityForQuery(world, result, world.queries.personNameAge, "personNameAge")

    setupSystem(spawnPersonName, spawnAge, spawnPerson)

    proc eachTick() =
        mySystem(personNameQuery, ageQuery, personNameAgeQuery)

    runner(eachTick)


# === End generated code

test "Basic system":
    myApp[100]()

