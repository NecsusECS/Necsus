import unittest, necsus

type GameState = enum
  Example

proc assertion() {.active(Example).} =
  discard

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~assertion], conf = newNecsusConf()).}

test "A system state should compile if no systems use it as an arg":
  myApp()
