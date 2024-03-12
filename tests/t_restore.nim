import unittest, necsus, sequtils

type
    RestoreMe1 = seq[string]
    RestoreMe2 = int

proc save1(): RestoreMe1 {.saveSys.} = discard

proc save2(): RestoreMe2 {.saveSys.} = discard

proc restore1(values: RestoreMe1, spawn: Spawn[(string, )]) {.restoreSys.} =
    for value in values:
        spawn.with(value)

proc restore2(value: RestoreMe2, shared: Shared[int]) {.restoreSys.} =
    shared := value

proc doRestore(restore: Restore, strings: Query[(string, )], shared: Shared[int]) =
    restore.fromString("""{"RestoreMe1": ["bar", "baz", "foo"], "RestoreMe2": 5}""")
    check(strings.toSeq.mapIt(it[0]) == ["bar", "baz", "foo"])
    check(shared.getOrRaise == 5)

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~save1, ~save2, ~restore1, ~restore2, ~doRestore], newNecsusConf()).}

test "Restoring system state from a string":
    myApp()
