import unittest, necsus, sequtils

proc spawner(spawn: Spawn[tuple[value: tuple[nested: string]]], global: Shared[tuple[value: string]]) =
    spawn.with(("foo", ))
    global := ("blah", )

proc assertion(query: Query[tuple[value: tuple[nested: string]]], global: Shared[tuple[value: string]]) =
    check(query.toSeq == @[(("foo", ), )])
    check(global == ("blah", ))

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [], [~spawner, ~assertion], [], newNecsusConf()).}

test "Systems should allow tuples as components":
    myApp()
