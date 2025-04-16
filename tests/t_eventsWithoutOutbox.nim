import unittest, necsus, sequtils

type SomeEvent = object

proc sender(receive: Inbox[SomeEvent]) =
  check(receive.toSeq.len == 0)

proc runner(tick: proc(): void) =
  tick()

proc testEvents() {.necsus(runner, [~sender], newNecsusConf()).}

test "Receiving events without any outboxes":
  testEvents()
