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

proc systemB(system: RegisterSystem) {.startupSys, active(StateB).} =
  system do() -> void:
    timesCalled += 1

proc runner(tick: proc(): void) =
  tick()
  tick()
  tick()
  tick()
  tick()
  tick()
  check timesCalled == 2

proc app() {.necsus(runner, [~systemA, ~systemB], newNecsusConf()).}

test "RegisterSystems should execute in the correct order":
  app()
