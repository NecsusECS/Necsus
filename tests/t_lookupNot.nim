import unittest, necsus, options

type
    A = int
    B = string
    C = float

proc spawn(ab: Spawn[(A, B)], abc: Spawn[(A, B, C)]) =
    ab.with(1, "foo")
    abc.with(2, "bar", 3.14)

proc assertions(query: FullQuery[(A, )], lookup: Lookup[(B, Not[C])]) =
    for eid, (a) in query:
        if a == 1:
            check(lookup(eid).get[0] == "foo")
        else:
            check(not lookup(eid).isSome)

proc runner(tick: proc(): void) = tick()

proc testLookup() {.necsus(runner, [~spawn, ~assertions], newNecsusConf()).}

test "Lookup with a 'Not' directive":
    testLookup()
