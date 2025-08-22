import unittest, necsus

type SomeRef = ref object
  str: string

proc one(intRef: Resource[ref int], objRef: Resource[SomeRef]) =
  check(intRef[] == 0)
  intRef[] += 1

  check(objRef.str == "foo")
  objRef.str = "bar"

proc two(intRef: Resource[ref int], objRef: Resource[SomeRef]) =
  check(intRef[] == 1)
  check(objRef.str == "bar")

proc runner(tick: proc(): void) =
  tick()

proc app(
  intRef: ref int = new(int), objRef: SomeRef = SomeRef(str: "foo")
) {.necsus(runner, [~one, ~two], newNecsusConf()).}

test "Pass resources from arguments to systems":
  app()
