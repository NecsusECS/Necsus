import unittest, necsus

type
    GameState = enum AOnly, BOnly, AAndB

const stateA = { AOnly, AAndB }
const stateB = { BOnly, AAndB }

proc always(accum: Shared[string]) =
    accum := accum.get("") & "|"

proc whenA(accum: Shared[string]) {.active(stateA).} =
    accum := accum.get("") & "A"

proc whenB(accum: Shared[string]) {.active(stateB).} =
    accum := accum.get("") & "B"

proc assertion(accum: Shared[string]) =
    check(accum.get == "||A|B|AB")

proc runner(state: Shared[GameState], tick: proc(): void) =
    tick()
    state := AOnly
    tick()
    state := BOnly
    tick()
    state := AAndB
    tick()

proc myApp() {.necsus(runner, [], [~always, ~whenA, ~whenB], [~assertion], conf = newNecsusConf()).}

test "Systems should only run when their state checks are met":
    myApp()


