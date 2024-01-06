import unittest, necsus, sequtils

type
    A = object
    B = object
    C = object
    D = object
    E = object

proc setup(spawnABCD: Spawn[(A, B, C, D)], spawnABCDE: Spawn[(A, B, C, D, E)]) =
    spawnABCD.with(A(), B(), C(), D())
    spawnABCDE.with(A(), B(), C(), D(), E())

proc detacher(query: FullQuery[(A, )], detach: Detach[(C, D, E)]) =
    for entityId, _ in query:
        detach(entityId)

proc assertions(
    findA: Query[(A, )],
    findB: Query[(B, )],
    findC: Query[(C, )],
    findD: Query[(D, )],
    findE: Query[(E, )]
) =
    check(findA.items.toSeq().len == 2)
    check(findB.items.toSeq().len == 2)
    check(findC.items.toSeq().len == 1)
    check(findD.items.toSeq().len == 1)
    check(findE.items.toSeq().len == 0)

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [~setup], [~detacher, ~assertions], [], newNecsusConf()).}

test "Detaching should require all components to be present":
    myApp()
