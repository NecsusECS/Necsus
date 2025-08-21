import unittest, necsus

proc testSystem(value: Resource[string]) =
  check(value == "Foo")

proc runner(tick: proc(): void) =
  tick()

proc app(value: string) {.necsus(runner, [~testSystem], newNecsusConf()).}

test "Pass resources from arguments to systems":
  app("Foo")

proc appWithDefault(
  value: string = "Foo"
) {.necsus(runner, [~testSystem], newNecsusConf()).}

test "Pass resources from default arguments to systems":
  appWithDefault()

test "Missing resource should fail to compile":
  check not(compiles do:
    proc appNoDefault() {.necsus(runner, [~testSystem], newNecsusConf()).})
