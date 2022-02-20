import unittest, necsus

type
    Thingy = object
        number: int

    Alias = Spawn[(Thingy, )]

    Alias2 = Alias

    Alias3 = Alias2

    SpawnTuple = (Thingy, )

proc withAlias(spawn: Alias, spawn2: Alias2, spawn3: Alias3, spawn4: Spawn[SpawnTuple]) =
    discard

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [], [~withAlias], [], newNecsusConf()).}

test "Directive aliases":
    myApp()
