import unittest, necsus

proc system1(someVar: Shared[string]) =
    someVar.set("foo")

proc system2(someVar: Shared[string]) =
    someVar.getOrRaise &= "bar"

proc assertion(someVar: Shared[string]) =
    check(someVar.get() == "foobar")

proc clearSys(someVar: Shared[string]) =
    check(someVar.isSome())
    someVar.clear()

proc checkClear(someVar: Shared[string]) =
    check(someVar.isEmpty())

proc runner(tick: proc(): void) =
    tick()

proc testSharedVar() {.necsus(runner, [~system1, ~system2, ~assertion, ~clearSys, ~checkClear], newNecsusConf()).}

test "Modifying the value in a shared variable":
    testSharedVar()
