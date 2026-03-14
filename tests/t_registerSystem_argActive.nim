import unittest, necsus

type SystemState = enum
  StateA
  StateB
  StateC

proc next[T: enum](value: T): T =
  return
    if value == high(T):
      low(T)
    else:
      value.succ

proc systemA(state: Shared[SystemState]) =
  if state.isEmpty:
    state := StateA
  else:
    state := state.get().next

var timesCalled = 0

proc systemB(
    bSys {.active(StateB).}: RegisterSystem, cSys {.active(StateC).}: RegisterSystem
) {.startupSys.} =
  bSys do() -> void:
    timesCalled += 1

  cSys do() -> void:
    timesCalled += 100

proc runner(tick: proc(): void) =
  tick()
  tick()
  tick()
  tick()
  tick()
  tick()
  check timesCalled == 202

proc app() {.necsus(runner, [~systemA, ~systemB], newNecsusConf()).}

test "RegisterSystems should execute in the correct order":
  app()
