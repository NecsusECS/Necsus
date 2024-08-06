import necsus/util/tools

# Blocked by: https://github.com/nim-lang/Nim/issues/23907
when isAboveNimVersion(2, 0, 8):
    import unittest, necsus

    type
        Thingy = object
            value: int

    proc `=copy`(target: var Thingy, source: Thingy) {.error.}

    proc spawner(spawn: Spawn[(Thingy, )]) =
        spawn.with(Thingy())

    proc runner(tick: proc(): void) = tick()

    proc myApp() {.necsus(runner, [~spawner], newNecsusConf()).}

    test "Spawning a value should not require a copy":
        myApp()
