import unittest, necsus

type SomeEvent = object

proc publish(sender: Outbox[SomeEvent]) =
  sender(SomeEvent())

proc runner(tick: proc(): void) =
  tick()

proc testEvents() {.necsus(runner, [~publish], newNecsusConf()).}

test "Sending events without any inboxes":
  testEvents()
