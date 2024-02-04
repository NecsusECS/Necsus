import unittest, necsus

type
    A = string

    B = object
        a: Shared[A]

proc logic(bundle: Bundle[B]): auto {.instanced.} =
    return proc() =
        bundle.a := "foo"

proc assertion(bundle: Bundle[B]) =
    check(bundle.a == "foo")

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~logic, ~assertion], conf = newNecsusConf()).}

test "Bundles used within an instanced system":
    myApp()

