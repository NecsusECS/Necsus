import unittest, necsus, options

type A = object
  value: string

proc assertNone(query: Query[(A,)]) =
  check(query.single.isNone)

proc setup(spawn: Spawn[(A,)]) =
  spawn.with(A(value: "foo"))

proc assertOne(query: Query[(A,)]) =
  check(query.single.get()[0].value == "foo")

proc runner(tick: proc(): void) =
  tick()

proc queryOne() {.necsus(runner, [~assertNone, ~setup, ~assertOne], newNecsusConf()).}

test "Pull a single value from a query":
  queryOne()
