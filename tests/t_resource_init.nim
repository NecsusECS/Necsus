import unittest, necsus

type Init = object
  str {.requiresInit.}: string

proc testSystem(value: Resource[Init]) =
  check(value.str == "Foo")

proc runner(tick: proc(): void) =
  tick()

proc app(value: Init) {.necsus(runner, [~testSystem], newNecsusConf()).}

test "Support resources that require initialization":
  app(Init(str: "Foo"))
