import unittest, necsus

var value: seq[string]

proc systemA(system: RegisterSystem) {.startupSys.} =
  system do() -> void:
    value.add("a")

proc systemB(system: RegisterSystem) {.startupSys.} =
  system do() -> void:
    value.add("b")

proc runner(tick: proc(): void) =
  tick()

proc app() {.necsus(runner, [~systemA, ~systemB], newNecsusConf()).}

test "RegisterSystems from multiple systems should all have their own storage":
  app()
  check "a" in value
  check "b" in value
