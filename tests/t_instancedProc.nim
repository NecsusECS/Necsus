import unittest, necsus

proc initSystem(create: Spawn[(string, )], query: Query[(string,)]): auto {.instanced.} =
    discard create.with("foo")
    discard create.with("bar")
    return proc() =
        check(query.len == 2)

proc runner(tick: proc(): void) =
    tick()
    tick()
    tick()

proc myApp() {.necsus(runner, [], [~initSystem], [], newNecsusConf()).}

test "Executed instanced systems that return procs":
    myApp()

