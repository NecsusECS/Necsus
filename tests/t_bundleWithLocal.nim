import unittest, necsus

type
    A = object
        foo: Local[string]
        bar: Local[string]

    B = object
        foo: Local[string]
        bar: Local[string]

proc assertion1*(a: Bundle[A], b: Bundle[B]) =
    a.foo := "foo"
    a.bar := "bar"
    b.foo := "baz"
    b.bar := "qux"

proc assertion2*(a: Bundle[A], b: Bundle[B]) =
    check(a.foo.getOrRaise == "foo")
    check(a.bar.getOrRaise == "bar")
    check(b.foo.getOrRaise == "baz")
    check(b.bar.getOrRaise == "qux")

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [~assertion1, ~assertion2], conf = newNecsusConf()).}

test "Bundles that contain Locals":
    myApp()
