import unittest, necsus

proc sys1(create: Spawn[(string, )], query: Query[(string,)]): auto {.instanced.} =
    create.with("foo")
    create.with("bar")
    return proc() =
        check(query.len == 2)

proc sys2(create: Spawn[(int, )], query: Query[(string,)]): SystemInstance =
    create.with(1)
    create.with(2)
    return proc() =
        check(query.len == 2)

proc buildSys2(): auto =
    return proc (create: Spawn[(float, )], query: Query[(float,)]): SystemInstance =
        create.with(1.0)
        create.with(2.0)
        return proc() =
            check(query.len == 2)

proc runner(tick: proc(): void) =
    tick()
    tick()
    tick()

let builtSys = buildSys2()

proc myApp() {.necsus(runner, [~sys1, ~sys2, ~builtSys], newNecsusConf()).}

test "Executed instanced systems that return procs":
    myApp()
