import unittest, necsus, options

type
    A = object
    B = object
    C = object

proc doLookup(lookup: Lookup[(A, B, C)]) =
    discard

proc runner(tick: proc(): void) = tick()

proc testLookup() {.necsus(runner, [], [~doLookup], [], newNecsusConf()).}

test "Lookups without any archetypes in the system":
    testLookup()
