import unittest, necsus, sequtils, math

type
    A = object
        a*: string
    B = object
        b*: string
    Wrap[T] = object
        value*: T
    WithStatic[T] = object
        value: T

proc setup(
    spawn: Spawn[(Wrap[A], Wrap[B])],
    shared: Shared[Wrap[A]],
    ordinal: Shared[WithStatic[123]],
    decimal: Shared[WithStatic[3.14]],
    str: Shared[WithStatic["asdf"]],
    boolean: Shared[WithStatic[true]],
    character: Shared[WithStatic['a']],
) =
    discard spawn.with(Wrap[A](value: A(a: "Foo")), Wrap[B](value: B(b: "Bar")))
    shared.set(Wrap[A](value: A(a: "Baz")))

    ordinal.set(WithStatic[123](value: 123))
    decimal.set(WithStatic[3.14](value: 3.14))
    str.set(WithStatic["asdf"](value: "asdf"))
    boolean.set(WithStatic[true](value: true))
    character.set(WithStatic['a'](value: 'a'))

proc assertion(
    all: Query[(Wrap[A], Wrap[B])],
    shared: Shared[Wrap[A]],
    ordinal: Shared[WithStatic[123]],
    decimal: Shared[WithStatic[3.14]],
    str: Shared[WithStatic["asdf"]],
    boolean: Shared[WithStatic[true]],
    character: Shared[WithStatic['a']],
) =
    check(toSeq(all.items).mapIt(it[0].value.a) == @["Foo"])
    check(toSeq(all.items).mapIt(it[1].value.b) == @["Bar"])
    check(shared.getOrRaise.value.a == "Baz")
    check(ordinal.getOrRaise.value == 123)
    check(decimal.getOrRaise.value == 3.14)
    check(str.getOrRaise.value == "asdf")
    check(boolean.getOrRaise.value == true)
    check(character.getOrRaise.value == 'a')

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [~setup], [~assertion], [], newNecsusConf()).}

test "Components with generic parameters":
    myApp()
