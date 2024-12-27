import unittest, necsus, std/options

type
    RestoreMe1 = string
    RestoreMe2 = int

proc restore1(value: RestoreMe1, store: Shared[RestoreMe1]) {.restoreSys.} =
    store := value

proc restore2(value: RestoreMe2, store: Shared[RestoreMe2]) {.restoreSys.} =
    store := value

proc doRestore(restore: Restore, store1: Shared[RestoreMe1], store2: Shared[RestoreMe2]) =
    restore("""{"RestoreMe1": "present"}""")
    check(store1 == "present")
    check(store2 == 0)

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~restore1, ~restore2, ~doRestore], newNecsusConf()).}

test "Restoring system state from a string with a missing key":
    myApp()
