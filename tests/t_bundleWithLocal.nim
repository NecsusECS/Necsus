import unittest, necsus

type
    A = object
        foo: Local[string]
        bar: Local[string]

    B = object
        foo: Local[string]
        bar: Local[string]

    C[T] = object
        data: Local[seq[T]]

proc assertion1*(a: Bundle[A], b: Bundle[B], c1: Bundle[C[string]], c2: Bundle[C[string]]) =
    a.foo := "foo"
    a.bar := "bar"
    b.foo := "baz"
    b.bar := "qux"

    c1.data := @[ "wakka" ]

proc assertion2*(a: Bundle[A], b: Bundle[B], c1: Bundle[C[string]], c2: Bundle[C[string]]) =
    check(a.foo == "foo")
    check(a.bar == "bar")
    check(b.foo == "baz")
    check(b.bar == "qux")

    check(c1.data == @[ "wakka" ])
    check(c2.data == @[ "wakka" ])

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [~assertion1, ~assertion2], conf = newNecsusConf()).}

test "Bundles that contain Locals":
    myApp()
