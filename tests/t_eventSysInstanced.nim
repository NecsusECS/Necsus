import unittest, necsus

proc publish(sender: Outbox[string]) =
    sender("foo")
    sender("bar")
    sender("baz")

proc receive(accum: Shared[string]): EventSystemInstance[string] {.eventSys.} =
    accum := "setup"
    return proc(event: string) =
        accum := accum.get & " " & event

proc runner(accum: Shared[string], tick: proc(): void) =
    tick()
    tick()
    check(accum.get == "setup foo bar baz foo bar baz")

proc testEvents() {.necsus(runner, [~publish, ~receive], newNecsusConf()).}

test "Triggering instanced event systems":
    testEvents()
