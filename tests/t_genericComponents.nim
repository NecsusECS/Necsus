import unittest, necsus, sequtils, necsus/runtime/packedIntTable, math

type
    A = object
        a*: string
    B = object
        b*: string
    Wrap[T] = object
        value*: T

proc setup(
    spawn: Spawn[(Wrap[A], Wrap[B])],
    shared: var Shared[Wrap[A]]
) =
    discard spawn((Wrap[A](value: A(a: "Foo")), Wrap[B](value: B(b: "Bar"))))
    shared.set(Wrap[A](value: A(a: "Baz")))

proc assertion(
    all: Query[(Wrap[A], Wrap[B])],
    shared: Shared[Wrap[A]]
) =
    check(toSeq(all.components).mapIt(it[0].value.a) == @["Foo"])
    check(toSeq(all.components).mapIt(it[1].value.b) == @["Bar"])
    check(shared.get().value.a == "Baz")

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [~setup], [~assertion], conf = newNecsusConf()).}

test "Components with generic parameters":
    myApp()
