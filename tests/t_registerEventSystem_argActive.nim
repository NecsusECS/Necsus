import unittest, necsus

type
  MyEvent = object
    value: int

  SystemState = enum
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

var receivedB: seq[int]
var receivedC: seq[int]

proc startup(
    handlerB {.active(StateB).}: RegisterEventSystem[MyEvent],
    handlerC {.active(StateC).}: RegisterEventSystem[MyEvent],
) {.startupSys.} =
  handlerB do(event: MyEvent) -> void:
    receivedB.add(event.value)
  handlerC do(event: MyEvent) -> void:
    receivedC.add(event.value)

proc sender(outbox: Outbox[MyEvent]) =
  outbox(MyEvent(value: 42))

proc runner(tick: proc(): void) =
  tick()
  tick()
  tick()
  tick()
  tick()
  tick()
  check receivedB == @[42, 42]
  check receivedC == @[42, 42]

proc app() {.necsus(runner, [~systemA, ~startup, ~sender], newNecsusConf()).}

test "RegisterEventSystem should only execute when active":
  app()
