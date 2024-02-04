import unittest, necsus

type
    A = object
        spawn: Spawn[(string, )]
        query: Query[(string, )]

    B = object
        a: Bundle[A]

    C = object
        b: Bundle[B]

proc setup*(bundle: Bundle[C]) =
    discard

proc assertion*(bundle: Bundle[C]) =
    discard

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~setup, ~assertion], conf = newNecsusConf()).}

test "Bundles nested inside other bundles":
    myApp()

