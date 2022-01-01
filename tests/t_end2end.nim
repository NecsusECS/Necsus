import unittest

import necsus

type
    Person = object
    Name = object
        name*: string
    Age = object
        age*: int

proc mySystem(people: Query[(Person, Name)], ages: Query[(Age, )]) =
    echo "starting mySystem"
    for (person, name) in people:
        echo "Person ", person, " named ", name.name

    for (age, ) in ages:
        echo "age ", age.age


# === Generated code

type
    MyAppComponents {.pure.} = enum Person, Name

    PersonNameQuery = object

proc myApp[initialSize: static int]() =

    # Metadata for all entities
    var entities = newSeq[EntityMetadata[MyAppComponents]](initialSize)

    # Sequences for all components
    var personComponents = newSeq[Person](initialSize)
    var nameComponents = newSeq[Name](initialSize)
    var agesComponents = newSeq[Age](initialSize)

    let personNameQuery = newQuery(
        proc (entityId: EntityId): (Person, Name) =
        (personComponents[entityId], nameComponents[entityId])
    )

    let ageQuery = newQuery(
        proc (entityId: EntityId): auto = (agesComponents[entityId], )
    )

    mySystem(personNameQuery, ageQuery)


# === End generated code

test "Basic system":
    myApp[100]()
