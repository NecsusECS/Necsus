import unittest, necsus

type GameState = enum
  AOnly
  BOnly
  AAndB

proc always(accum: Shared[string]) =
  accum := accum.get("") & "|"

proc whenA(accum: Shared[string]) {.active(AOnly, AAndB).} =
  accum := accum.get("") & "A"

proc whenB(accum: Shared[string]) {.active(BOnly, AAndB).} =
  accum := accum.get("") & "B"

proc assertion(accum: Shared[string]) {.teardownSys.} =
  check(accum.get == "||A|B|AB")

proc runner(state: Shared[GameState], tick: proc(): void) =
  tick()
  state := AOnly
  tick()
  state := BOnly
  tick()
  state := AAndB
  tick()

proc myApp() {.
  necsus(runner, [~always, ~whenA, ~whenB, ~assertion], conf = newNecsusConf())
.}

test "Systems should only run when their state checks are met":
  myApp()
