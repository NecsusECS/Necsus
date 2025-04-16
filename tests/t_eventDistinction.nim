import unittest, necsus, sequtils

type
  EventA = int

  EventB = int

proc publish(sendA: Outbox[EventA], sendB: Outbox[EventB]) =
  sendA(123)
  sendB(456)

proc receive(receiveA: Inbox[EventA], receiveB: Inbox[EventB]) =
  check(receiveA.toSeq == @[123])
  check(receiveB.toSeq == @[456])

proc runner(tick: proc(): void) =
  tick()

proc testEvents() {.necsus(runner, [~publish, ~receive], newNecsusConf()).}

test "Events with different names should have distinct mailboxes":
  testEvents()
