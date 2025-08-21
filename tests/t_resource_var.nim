import unittest, necsus

type Init = object
  str: string

proc one(value: var Resource[Init]) =
  check(value.str == "Foo")
  value.str = "Bar"

proc two(value: Resource[Init]) =
  check(value.str == "Bar")

proc runner(tick: proc(): void) =
  tick()

proc app(value: Init) {.necsus(runner, [~one, ~two], newNecsusConf()).}

test "Support resources as vars":
  app(Init(str: "Foo"))
