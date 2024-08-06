import necsus/util/tools

# Blocked by: https://github.com/nim-lang/Nim/issues/23907
when isAboveNimVersion(2, 0, 8):
    import unittest, necsus

    type
        Thingy = object
            value: int

    proc `=copy`(a: var Thingy, b: Thingy) {.error.}

    var thingyDestroyCount = 0

    {.warning[Deprecated]:off.}
    proc `=destroy`(thingy: var Thingy) =
        if thingy.value == 123:
            assert(thingyDestroyCount <= 0)
            thingyDestroyCount += 1

    proc destroyObj(spawn: FullSpawn[(Thingy, )], delete: Delete) =
        require(thingyDestroyCount == 0)
        let eid = spawn.with(Thingy(value: 123))
        require(thingyDestroyCount == 0)
        delete(eid)
        require(thingyDestroyCount == 1)

    proc runner(tick: proc(): void) = tick()

    proc myApp() {.necsus(runner, [~destroyObj], newNecsusConf()).}

    test "Deleting entities should call destroy on their components":
        myApp()
