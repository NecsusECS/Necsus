import unittest, necsus, sequtils

type
    Multiply = object
        value*: int
    Add = object
        value*: int

proc setup(spawn: Spawn[(Multiply, Add)]) =
    for i in 1..5:
        discard spawn((Multiply(value: i), Add(value: i)))

proc operate(query: Query[tuple[mult: ptr Multiply, add: ptr Add]]) =
    for _, entity in query:
        entity.mult.value = entity.mult.value * entity.mult.value
        entity.add.value = entity.add.value + entity.add.value

proc assertion(query: Query[tuple[mult: Multiply, add: Add]]) =
    check(toSeq(query.items).mapIt(it.mult.value) == @[1, 4, 9, 16, 25])
    check(toSeq(query.items).mapIt(it.add.value) == @[2, 4, 6, 8, 10])

proc runner(tick: proc(): void) =
    tick()

proc pointerQuery() {.necsus(runner, [~setup], [~operate, ~assertion], [], newNecsusConf()).}

test "Query and update components by pointer":
    pointerQuery()
