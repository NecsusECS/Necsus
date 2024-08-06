import necsus/util/tools

# Blocked by: https://github.com/nim-lang/Nim/issues/23907
when isAboveNimVersion(2, 0, 8):
    import unittest, necsus

    type
        A = object
        B = object

    proc `=copy`(x: var A, y: A) {.error.}
    proc `=copy`(x: var B, y: B) {.error.}

    proc exec(spawn: FullSpawn[(A, B)], detach: Detach[(B, )]) =
        detach(spawn.with(A(), B()))

    proc runner(tick: proc(): void) =
        tick()

    proc testDetach() {.necsus(runner, [~exec], newNecsusConf()).}

    test "Detaching components without requiring a copy":
        testDetach()
