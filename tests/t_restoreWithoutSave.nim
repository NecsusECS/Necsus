import unittest, necsus

type
    A = seq[string]

    B = int

proc restoreA(values: A) {.restoreSys.} =
    discard

proc saveA(): A {.saveSys.} =
    return @[ "a", "b", "c" ]

proc restoreB(value: B) {.restoreSys.} =
    discard

proc doSave(save: Save, restore: Restore) =
    let saved = save()
    check(saved == """{"A":["a","b","c"]}""")
    restore(saved)

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~restoreA, ~saveA, ~restoreB, ~doSave], newNecsusConf()).}

test "Restore system without a matching save should not produce JSON":
    myApp()
