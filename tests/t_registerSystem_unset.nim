import unittest, necsus

proc testSystem(a: RegisterSystem, b: RegisterSystem) {.startupSys.} =
  discard

proc runner(tick: proc(): void) =
  tick()
  tick()
  tick()

proc app() {.necsus(runner, [~testSystem], newNecsusConf()).}

test "Registered systems that are never used should work":
  app()
