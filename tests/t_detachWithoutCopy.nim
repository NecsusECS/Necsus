import necsus/util/tools

when isSinkMemoryCorruptionFixed():
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
