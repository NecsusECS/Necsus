import unittest, necsus

proc sampleSystem(
  a {.inject.}: TimeDelta,
  b {.inject.}: Shared[string],
  c {.inject.}: Lookup[(int, )],
  swap {.inject.}: Swap[(int, ), (string, )]
) =
  discard

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~sampleSystem], newNecsusConf()).}

test "Systems with pragmas on their args should parse":
  myApp()
