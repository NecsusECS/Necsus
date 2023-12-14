import unittest, necsus, options

type A = object

const create = proc (spawn: Spawn[(A, )]) =
    spawn.with(A())
    spawn.with(A())
    spawn.with(A())

const check = proc (query: Query[(A, )]) =
    check(query.len == 3)

proc runner(tick: proc(): void) = tick()

proc variableApp() {.necsus(runner, [], [~create], [], newNecsusConf()).}

test "Allow systems to be create from variables":
    variableApp()
