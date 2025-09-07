import unittest, necsus, options

type A = object

proc exec(create: Spawn[(typeOf(A()),)], query: Query[(typeOf(A()),)]) =
  create.with(A())
  check query.len == 1

proc runner(tick: proc(): void) =
  tick()

proc app() {.necsus(runner, [~exec], newNecsusConf()).}

test "Allow 'typeOf' directives":
  app()
