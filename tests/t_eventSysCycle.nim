import unittest, necsus

proc trigger(send: Outbox[string]) {.startupSys.} =
  send("Start")

proc systemA(event: string, send: Outbox[int], accum: Shared[string]) {.eventSys.} =
  send(123)
  accum := accum.get & event

proc systemB(event: int, send: Outbox[string], accum: Shared[string]) {.eventSys.} =
  send("foo")
  accum := accum.get & $event

proc runner(accum: Shared[string], tick: proc(): void) =
  tick()
  tick()
  check(accum.get == "Start123foo123")

proc testEvents() {.necsus(runner, [~trigger, ~systemA, ~systemB], newNecsusConf()).}

test "Events that trigger a circular eventSys should cut the cycle":
  testEvents()
