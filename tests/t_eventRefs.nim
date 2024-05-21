import unittest, necsus

type SomeEvent = ref object
    value: int

proc sender(count: Local[int], emit: Outbox[SomeEvent]) =
    count := count.get(0) + 1
    for i in 0..count.get:
        emit(SomeEvent(value: i))

proc receiveOne(receive: Inbox[SomeEvent], accum: Shared[int]) =
    for event in receive:
        accum := accum.get + event.value

proc receiveTwo(receive: SomeEvent, accum: Shared[int]) {.eventSys.} =
    accum := accum.get + receive.value

proc runner(accum: Shared[int], tick: proc(): void) =
    for i in 0..<500:
        tick()
    check(accum.get == 41917000)

proc testEvents() {.necsus(runner, [~sender, ~receiveOne, ~receiveTwo], newNecsusConf()).}

test "Bulk sending events as refs":
    testEvents()
