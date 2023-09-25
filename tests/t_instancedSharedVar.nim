import unittest, necsus

proc initSystem(ours: Shared[string], mine: Local[string]): auto {.instanced.} =
    ours := "foo"
    mine := "bar"
    return proc() =
        check(ours.get == "qux")
        check(mine.get == "bar")

proc assertions(ours: Shared[string]) =
    check(ours.get == "foo")
    ours := "qux"

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [], [~assertions, ~initSystem], [], newNecsusConf()).}

test "Allow system variables to be instanced":
    myApp()

