import unittest, necsus

var value = 0

proc systemA() =
  check value == 0
  value += 1

proc systemB(system: RegisterSystem) {.startupSys.} =
  system do() -> void:
    check value == 1
    value += 1

proc systemC() =
  check value == 2

proc runner(tick: proc(): void) =
  tick()

proc app() {.necsus(runner, [~systemA, ~systemB, ~systemC], newNecsusConf()).}

test "RegisterSystems should execute in the correct order":
  app()
