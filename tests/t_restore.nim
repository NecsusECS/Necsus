import unittest, necsus, sequtils

type
  RestoreMe1 = seq[string]
  RestoreMe2 = int
  RestoreMe3 = ref object
    number: int

proc restore1(values: RestoreMe1, spawn: Spawn[(string,)]) {.restoreSys.} =
  for value in values:
    spawn.with(value)

proc restore2(value: RestoreMe2, shared: Shared[int]) {.restoreSys.} =
  shared := value

proc restore3(value: RestoreMe3, shared: Shared[RestoreMe3]) {.restoreSys.} =
  shared := value

proc doRestore(
    restore: Restore,
    strings: Query[(string,)],
    restore2: Shared[int],
    restore3: Shared[RestoreMe3],
) =
  restore(
    """{"RestoreMe1": ["bar", "baz", "foo"], "RestoreMe2": 5, "RestoreMe3": {"number": 7}}"""
  )
  check(strings.toSeq.mapIt(it[0]) == ["bar", "baz", "foo"])
  check(restore2.getOrRaise == 5)
  check(restore3.getOrRaise.number == 7)

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.
  necsus(runner, [~restore1, ~restore2, ~restore3, ~doRestore], newNecsusConf())
.}

test "Restoring system state from a string":
  myApp()
