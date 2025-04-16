import unittest, necsus

type SaveMe = seq[string]

proc save(): SaveSystemInstance[SaveMe] {.saveSys.} =
  return proc(): SaveMe =
    return @["a", "b", "c"]

proc doSave(save: Save) =
  check(save() == """{"SaveMe":["a","b","c"]}""")

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~save, ~doSave], newNecsusConf()).}

test "Allow saveSys sytems to be instanced":
  myApp()
