import unittest, necsus

type
    SomeEvent = int

proc buildSystem(): auto =
    return proc(listen: Inbox[SomeEvent], accum: Shared[int]) =
        for value in listen:
            accum := accum.get + value

proc sender(send: Outbox[SomeEvent]) =
    send(7)
    send(1)

let first = buildSystem()
let second = buildSystem()

proc assertions(accum: Shared[int]) =
    check(accum.get == 16)

proc runner(tick: proc(): void) =
    tick()

proc testEvents() {.necsus(runner, [~sender, ~first, ~second, ~assertions], newNecsusConf()).}

test "Unique inboxes for systems assigned to variables":
    testEvents()
