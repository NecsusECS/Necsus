import unittest, necsus, options

type
    A = object
        value: int
    B = object
        value: string
    C = object

proc spawn(spawn: Spawn[(A, B)]) =
    discard spawn((A(value: 1), B(value: "foo")))
    discard spawn((A(value: 2), B(value: "bar")))

proc assertions(
    query: Query[tuple[a: A, b: B]],
    lookupA: Lookup[tuple[a: A, ]],
    lookupB: Lookup[tuple[b: B, ]],
    lookupAB: Lookup[tuple[a: A, b: B]],
    lookupABC: Lookup[(A, B, C)]
) =
    for (eid, comp) in query:
        check(eid.lookupA().get().a == comp.a)
        check(eid.lookupB().get().b == comp.b)
        check(eid.lookupAB().get().a == comp.a)
        check(eid.lookupAB().get().b == comp.b)
        check(eid.lookupABC().isNone)

proc runner(tick: proc(): void) = tick()

proc testLookup() {.necsus(runner, [~spawn], [~assertions], conf = newNecsusConf()).}

test "Looking up components by entity Id":
    testLookup()
