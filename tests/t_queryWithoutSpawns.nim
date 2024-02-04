import unittest, necsus

type
    A = object
    B = object
    C = object
    D = object

proc query1(query: Query[(A, B)]) =
    discard

proc query2(query: Query[(C, D)]) =
    discard

proc spawner(spawns: Spawn[(C, )]) =
    discard

proc runner(tick: proc(): void) = tick()

proc noSpawnQuery() {.necsus(runner, [~spawner, ~query1, ~query2], newNecsusConf()).}

test "Querying for components that have never been spawned":
    noSpawnQuery()
