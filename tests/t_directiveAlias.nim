import unittest, necsus, sequtils, times

type
    Thingy = object
        number: int

    Alias = Spawn[(Thingy, )]

    Alias2 = Alias

    Alias3 = Alias2

proc withAlias(spawn: Alias, spawn2: Alias2, spawn3: Alias3) =
    discard

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [], [~withAlias], [], newNecsusConf()).}

test "Directive aliases":
    myApp()
