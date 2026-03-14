import unittest, necsus

type MyEvent = int

var received: seq[int]
var recordValue = 0

proc register(exec: RegisterSystem, events: RegisterEventSystem[MyEvent]) =
  recordValue += 1

  events do(event: MyEvent) -> void:
    received.add(event + recordValue)

  exec do() -> void:
    received.add(recordValue)

proc sender(outbox: Outbox[MyEvent]) =
  outbox(100)

proc runner(tick: proc(): void) =
  tick()
  tick()
  tick()

proc app() {.necsus(runner, [~register, ~sender], newNecsusConf()).}

test "Registering systems in a loop system":
  app()
  check received == @[1, 101, 2, 102, 3, 103]
