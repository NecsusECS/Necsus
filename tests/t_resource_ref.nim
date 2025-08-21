import unittest, necsus

proc one(value: Resource[ref int]) =
  check(value[] == 0)
  value[] += 1

proc two(value: Resource[ref int]) =
  check(value[] == 1)

proc runner(tick: proc(): void) =
  tick()

proc app(value: ref int = new(int)) {.necsus(runner, [~one, ~two], newNecsusConf()).}

test "Pass resources from arguments to systems":
  app()
