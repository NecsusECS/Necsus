import unittest, necsus

proc publish(sender: Outbox[string]) =
  sender("foo ")
  sender("bar ")
  sender("baz ")

proc receive(event: string, accum: Shared[string]) {.eventSys.} =
  accum := accum.get & event

proc runner(accum: Shared[string], tick: proc(): void) =
  tick()
  tick()
  check(accum.get == "foo bar baz foo bar baz ")

proc testEvents() {.necsus(runner, [~publish, ~receive], newNecsusConf()).}

test "Triggering event systems":
  testEvents()
