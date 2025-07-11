import necsus/util/tools

when isSpawnSinkEnabled():
  import unittest, necsus

  type Thingy = object
    value: int

  proc `=copy`(target: var Thingy, source: Thingy) {.error.}

  proc spawner(spawn: Spawn[(Thingy,)]) =
    spawn.with(Thingy())

  proc runner(tick: proc(): void) =
    tick()

  proc myApp() {.necsus(runner, [~spawner], newNecsusConf()).}

  test "Spawning a value should not require a copy":
    myApp()
