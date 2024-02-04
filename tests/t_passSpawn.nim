import unittest, necsus

type A = object

proc new*(spawn: Spawn[(A, )]) =
    spawn.with(A())

proc spawner(spawn: Spawn[(A, )]) =
    spawn.new()

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.used, necsus(runner, [~spawner], newNecsusConf()).}

test "Passing spawn instance to another function":
    myApp()
