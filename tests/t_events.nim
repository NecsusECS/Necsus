import unittest, necsus, sequtils

type
    SomeEvent = object
        value: int

var iterations = 0

proc publish(sender: Outbox[SomeEvent], loneOutbox: Outbox[string]) =
    for i in 1..3:
        sender(SomeEvent(value: i + iterations))

proc receive(receiver: Inbox[SomeEvent], loneInbox: Inbox[int]) =
    check(receiver.len == 3)
    check(receiver.toSeq == @[
        SomeEvent(value: iterations + 1),
        SomeEvent(value: iterations + 2),
        SomeEvent(value: iterations + 3)
    ])

proc runner(tick: proc(): void) =
    tick()
    iterations += 10
    tick()
    iterations += 10
    tick()

proc testEvents() {.necsus(runner, [~publish, ~receive], newNecsusConf()).}

test "Sending and receiving values":
    testEvents()
