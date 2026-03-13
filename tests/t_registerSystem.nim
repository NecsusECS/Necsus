import unittest, necsus

var stored = 0

proc testSystem(updater: RegisterSystem, checker: RegisterSystem) {.startupSys.} =
  check stored == 0

  var value = 0

  updater do() -> void:
    value += 1

  checker do() -> void:
    check value == (stored + 1)
    stored = value

proc runner(tick: proc(): void) =
  tick()
  tick()
  tick()

proc app() {.necsus(runner, [~testSystem], newNecsusConf()).}

test "Execute registered systems":
  app()
  check stored == 3
