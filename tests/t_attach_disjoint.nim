import unittest, necsus, sequtils

type
    Name = string
    Age = int
    Stunned {.accessory.} = object

    Item = object
    Title = string
    Broken {.accessory.} = object

proc setup(person: Spawn[(Age, Name)], inventory: Spawn[(Item, Title)]) =
    person.with(31, "Jack")
    inventory.with(Item(), "Sword")
    inventory.with(Item(), "Dagger")

proc breakItems(inventory: FullQuery[(Item, )], broken: Attach[(Broken, )]) =
    for entityId, _ in inventory:
        entityId.broken((Broken(), ))

proc stunPeople(people: FullQuery[(Name, )], stun: Attach[(Stunned, )]) =
    for entityId, _ in people:
        entityId.stun((Stunned(), ))

proc assertions(
    broken: Query[(Broken, Title)],
    stunned: Query[(Stunned, Name)],
) =
    check(toSeq(broken.items).mapIt(it[1]) == @["Sword", "Dagger"])
    check(toSeq(stunned.items).mapIt(it[1]) == @["Jack"])

proc runner(tick: proc(): void) =
    tick()

proc testAttaches() {.necsus(runner, [~setup, ~breakItems, ~stunPeople, ~assertions], newNecsusConf()).}

test "Attach with disjoin archetypes present":
    testAttaches()
