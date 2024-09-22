import unittest, necsus, sequtils

type
    GameState = enum StateA, StateB

    SomeEvent = int

proc publish(sender: Outbox[SomeEvent], i: Shared[int]) =
    sender(i.get)

proc receiveBefore1(receiver: Inbox[SomeEvent]) {.active(StateB).} =
    check(receiver.toSeq == @[ 1 ])

proc receiveBefore2(value: SomeEvent) {.active(StateB), eventSys.} =
    check(value == 1)

proc receiveBefore3(value: SomeEvent, _: Outbox[string]) {.active(StateB), eventSys.} =
    check(value == 1)

proc changeState(state: Shared[GameState]) =
    state := StateB

proc receiveAfter1(receiver: Inbox[SomeEvent], i: Shared[int]) {.active(StateB).} =
    if i.get == 0:
        check(receiver.len == 0)
    else:
        check(receiver.toSeq == @[ 1 ])

proc receiveAfter2(value: SomeEvent) {.active(StateB), eventSys.} =
    check(value == 1)

proc receiveAfter3(value: SomeEvent, _: Outbox[string]) {.active(StateB), eventSys.} =
    check(value == 1)

proc runner(i: Shared[int], tick: proc(): void) =
    i := 0
    tick()
    i := 1
    tick()

proc testEvents() {.necsus(runner, [
    ~publish,
    ~receiveBefore1,
    ~receiveBefore2,
    ~receiveBefore3,
    ~changeState,
    ~receiveAfter1,
    ~receiveAfter2,
    ~receiveAfter3,
], newNecsusConf()).}

test "Events should not be sent to disabled systems":
    testEvents()
