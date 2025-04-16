import unittest, necsus, sequtils

type
  BaseSpawn[T] = Spawn[(T, string)]

  BaseQuery[T] = Query[(T, string)]

proc spawner(spawnInt: BaseSpawn[int], spawnFloat: BaseSpawn[float]) =
  spawnInt.with(123, "foo")
  spawnFloat.with(3.14, "bar")

proc verify(queryInt: BaseQuery[int], queryFloat: BaseQuery[float]) =
  check(queryInt.toSeq == @[(123, "foo")])
  check(queryFloat.toSeq == @[(3.14, "bar")])

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~spawner, ~verify], conf = newNecsusConf()).}

test "Directives aliase with generic parameters":
  myApp()
