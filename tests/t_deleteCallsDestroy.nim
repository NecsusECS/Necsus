import unittest, necsus

type
    Thingy = object
        value: int

var thingyDestroyCount = 0

proc `=destroy`(thingy: var Thingy) =
    if thingy.value == 123:
        thingyDestroyCount += 1

proc destroyObj(spawn: Spawn[(Thingy, )], delete: Delete) =
    check(thingyDestroyCount == 0)
    let eid = spawn.with(Thingy(value: 123))
    check(thingyDestroyCount == 0)
    delete(eid)
    check(thingyDestroyCount == 1)

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [], [~destroyObj], [], newNecsusConf()).}

test "Deleting entities should call destroy on their components":
    myApp()
