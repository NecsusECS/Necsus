import unittest, necsus

proc publish(sender: Outbox[string]) =
    sender("foo")
    sender("bar")
    sender("baz")

proc receive(accum: Shared[string]): auto {.eventSys, instanced.} =
    accum := "setup"
    return proc(event: string) =
        accum := accum.get & " blah"

        # The following should work, but breaks with an internal Nim compiler error:
        # accum := accum.get & event

proc runner(accum: Shared[string], tick: proc(): void) =
    tick()
    tick()
    check(accum.get == "setup blah blah blah blah blah blah")

proc testEvents() {.necsus(runner, [~publish, ~receive], newNecsusConf()).}

test "Triggering instanced event systems":
    testEvents()
