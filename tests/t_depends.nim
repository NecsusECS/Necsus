import unittest, necsus

type Accum = object
    data: string

proc creator(spawn: Spawn[(Accum, )]) =
    spawn.with(Accum(data: "create"))

proc buildSystem(): auto =
    return proc (query: Query[(ptr Accum,)]) =
        for (elem, ) in query: elem.data &= " update"

let update {.depends(creator), used.} = buildSystem()

proc update2(query: Query[(ptr Accum,)]) {.depends(update).} =
    for (elem, ) in query: elem.data &= " another"

proc update3(query: Query[(ptr Accum,)]) {.depends(update2).} =
    for (elem, ) in query: elem.data &= " also"

proc assertion(query: Query[(Accum,)]) {.depends(update2, update3).} =
    check(query.len == 1)
    for (elem, ) in query:
        check(elem.data == "create update another also")

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [], [~assertion], [], newNecsusConf()).}

test "Depending on other systems":
    myApp()
