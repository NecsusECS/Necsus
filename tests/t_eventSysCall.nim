import unittest, necsus

proc publish(sender: Outbox[string]) =
    sender("foo")

proc receive(event: string, accum: Shared[string]) {.eventSys().} =
    accum := event

proc runner(accum: Shared[string], tick: proc(): void) =
    tick()
    check(accum.get == "foo")

proc testEvents() {.necsus(runner, [~publish, ~receive], newNecsusConf()).}

test "Triggering event systems when defined as pragma calls":
    testEvents()
