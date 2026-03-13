import unittest, necsus

type MyEvent = object
  value: int

var received: seq[int]

proc startup(register: RegisterEventSystem[MyEvent]) {.startupSys.} =
  register do(event: MyEvent) -> void:
    received.add(event.value)

proc sender(outbox: Outbox[MyEvent]) =
  outbox(MyEvent(value: 42))

proc runner(tick: proc(): void) =
  tick()
  tick()
  tick()

proc app() {.necsus(runner, [~startup, ~sender], newNecsusConf()).}

test "RegisterEventSystem receives events":
  app()
  check received == @[42, 42, 42]
