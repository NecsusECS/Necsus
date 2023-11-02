import unittest, necsus

proc system1(someVar: Shared[string]) =
    someVar.set("foo")

proc system2(someVar: Shared[string]) =
    someVar.getOrRaise &= "bar"

proc assertion(someVar: Shared[string]) =
    check(someVar.get() == "foobar")

proc runner(tick: proc(): void) =
    tick()

proc testSharedVar() {.necsus(runner, [], [~system1, ~system2, ~assertion], [], newNecsusConf()).}

test "Modifying the value in a shared variable":
    testSharedVar()
