import unittest, necsus, options, sequtils

type
    A = object
        value: int
    B = object
        value: string
    C = object

proc spawn(spawn: Spawn[(A, B)]) =
    spawn.with(A(value: 1), B(value: "foo"))
    spawn.with(A(value: 2), B(value: "bar"))

proc assertions(
    query: FullQuery[tuple[a: A, b: B]],
    lookupA: Lookup[tuple[a: A, ]],
    lookupB: Lookup[tuple[b: B, ]],
    lookupAB: Lookup[tuple[a: A, b: B]],
    lookupABC: Lookup[(A, B, C)]
) =
    for eid, comp in query:
        check(eid.lookupA().get().a == comp.a)
        check(eid.lookupB().get().b == comp.b)
        check(eid.lookupAB().get().a == comp.a)
        check(eid.lookupAB().get().b == comp.b)
        check(eid.lookupABC().isNone)

proc runner(tick: proc(): void) = tick()

proc testLookup() {.necsus(runner, [~spawn, ~assertions], newNecsusConf()).}

test "Looking up components by entity Id":
    testLookup()

proc modify(query: FullQuery[tuple[a: A, b: B]], lookup: Lookup[tuple[a: ptr A, b: ptr B]]) =
    for eid, _ in query:
        eid.lookup().get().a.value = eid.lookup().get().a.value * 2
        eid.lookup().get().b.value = eid.lookup().get().b.value & "bar"

proc assertModifications(query: Query[tuple[a: A, b: B]]) =
    check(query.items.toSeq.mapIt(it.a.value) == @[2, 4])
    check(query.items.toSeq.mapIt(it.b.value) == @["foobar", "barbar"])

proc testLookupWithPointers() {.necsus(runner, [~spawn, ~modify, ~assertModifications], newNecsusConf()).}

test "Modifying components from a lookup":
    testLookupWithPointers()
