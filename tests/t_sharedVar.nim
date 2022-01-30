import unittest, necsus

proc system1(shared1: var Shared[int], shared2: var Shared[string]) =
    if shared1.isEmpty: shared1.set(123) else: check(shared1.get() == 246)
    if shared2.isEmpty: shared2.set("foo") else: check(shared2.get() == "foobar")

proc system2(shared1: var Shared[int], shared2: var Shared[string]) =
    shared1.set(shared1.get() * 2)
    shared2.set(shared2.get() & "bar")

proc assertions(shared1: Shared[int], shared2: Shared[string]) =
    check(shared1.get() in [246, 492])
    check(shared2.get() in ["foobar", "foobarbar"])

proc runTwice(tick: proc(): void) =
    tick()
    tick()

proc testSharedVar() {.necsus(runTwice, [], [~system1, ~system2, ~assertions], [], newNecsusConf()).}

test "Assigning and reading shared system vars":
    testSharedVar()



proc runOnce(tick: proc(): void) = tick()

proc assertAppInputs(strInput: Shared[string], intInput: Shared[int]) =
    assert(strInput.get() == "blah blah")

proc testSharedVarArg(strInput: string, intInput: int, unmentioned: float) {.necsus(
    runTwice,
    [],
    [~assertAppInputs],
    [],
    newNecsusConf())
.}

test "Assigning shared variables from app arguments":
    testSharedVarArg("blah blah", 123, 3.14)
