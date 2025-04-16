import unittest, necsus, sequtils

type Components[T] = (T, string)

proc spawner(spawnInt: Spawn[Components[int]], spawnFloat: Spawn[Components[float]]) =
  spawnInt.with(123, "foo")
  spawnFloat.with(3.14, "bar")

proc verify(queryInt: Query[Components[int]], queryFloat: Query[Components[float]]) =
  check(queryInt.toSeq == @[(123, "foo")])
  check(queryFloat.toSeq == @[(3.14, "bar")])

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~spawner, ~verify], conf = newNecsusConf()).}

test "Directives with generics for component list":
  myApp()
