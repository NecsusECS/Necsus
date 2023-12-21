import unittest, necsus

type
    GameState = enum StateA, StateB

    SomeEvent = object


proc publish(sender: Outbox[SomeEvent]) =
    sender(SomeEvent())

proc receive(receiver: Inbox[SomeEvent]) {.active(StateB).} =
    check(receiver.len == 1)

proc changeState(state: Shared[GameState]) =
    state := StateB

proc runner(tick: proc(): void) =
    tick()
    tick()

proc testEvents() {.necsus(runner, [], [~publish, ~receive, ~changeState], [], newNecsusConf()).}

test "Events should not be sent to disabled systems":
    testEvents()
