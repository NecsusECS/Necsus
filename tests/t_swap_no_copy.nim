import necsus, std/unittest, necsus/util/tools

when isSpawnSinkEnabled():
  type
    A = object
    B = object
    C = object
      value: int

    D = object
      value: int

  proc `=copy`(a: var A, b: A) {.error.}

  proc `=copy`(a: var B, b: B) {.error.}

  proc `=copy`(a: var C, b: C) {.error.}

  proc `=copy`(a: var D, b: D) {.error.}

  proc exec(
      create: FullSpawn[(A, B)],
      change: Swap[(C, D), (A, B)],
      values: Query[(ptr C, ptr D)],
  ) =
    create.with(A(), B()).change((C(value: 1), D(value: 2)))
    check(values.len == 1)

    for (c, d) in values:
      check(c.value == 1)
      check(d.value == 2)

  proc runner(tick: proc(): void) =
    tick()

  proc testswap() {.necsus(runner, [~exec], newNecsusConf()).}

  test "Swapping components without copies":
    testswap()
