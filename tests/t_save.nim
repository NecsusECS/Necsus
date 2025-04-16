import unittest, necsus, sequtils, algorithm

proc spawn(spawn: Spawn[(string,)]) =
  spawn.with("foo")
  spawn.with("bar")
  spawn.with("baz")

type
  SaveMe1 = seq[string]
  SaveMe2 = int
  SaveMe3 = ref object
    number: int

proc save1(values: Query[(string,)]): SaveMe1 {.saveSys.} =
  return values.mapIt(it[0]).sorted()

proc save2(): SaveMe2 {.saveSys.} =
  return 5

proc save3(): SaveMe3 {.saveSys.} =
  return SaveMe3(number: 7)

proc doSave(save: Save) =
  check(
    save() == """{"SaveMe1":["bar","baz","foo"],"SaveMe2":5,"SaveMe3":{"number":7}}"""
  )

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.
  necsus(runner, [~spawn, ~save1, ~save2, ~save3, ~doSave], newNecsusConf())
.}

test "Creating JSON from saveSys procs":
  myApp()
