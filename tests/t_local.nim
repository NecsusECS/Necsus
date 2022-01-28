import unittest, necsus

proc system1(local1: var Local[string], local2: var Local[string]) =
    if local1.isEmpty: local1.set("foo") else: check(local1.get() == "foo")
    if local2.isEmpty: local2.set("baz") else: check(local2.get() == "baz")

proc system2(local: var Local[string]) =
    if local.isEmpty:
        local.set("bar")
    else:
        check(local.get() == "bar")

proc runner(tick: proc(): void) =
    tick()
    tick()
    tick()

proc testLocalVar() {.necsus(runner, [], [~system1, ~system2], conf = newNecsusConf()).}

test "Assigning and reading local system vars":
    testLocalVar()
