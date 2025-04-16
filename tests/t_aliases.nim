import unittest, sequtils, necsus

type
  Thingy = object
    value: string

  Whatsit = Thingy
  Whosit = Thingy
  Whysit = Thingy
  Whensit = Thingy

  ParametricAlias[T] = proc(spawn: Spawn[(T,)]): void
  ExactAlias = proc(spawn: Spawn[(Whysit,)]): void
  AliasAlias = ParametricAlias[Whensit]

proc spawner[T](value: string): proc(spawn: Spawn[(T,)]): void =
  return proc(spawn: Spawn[(T,)]) =
    spawn.with(T(value: value))

let spawn1 = spawner[Thingy]("first")
let spawn2: proc(spawn: Spawn[(Whatsit,)]): void = spawner[Whatsit]("second")
let spawn3: ParametricAlias[Whosit] = spawner[Whosit]("third")
let spawn4: ExactAlias = spawner[Whysit]("fourth")
let spawn5: AliasAlias = spawner[Whensit]("fifth")

proc assertion(
    thingies: Query[(Thingy,)],
    whatsits: Query[(Whatsit,)],
    whosits: Query[(Whosit,)],
    whysit: Query[(Whysit,)],
    whensit: Query[(Whensit,)],
) =
  check(toSeq(thingies.items).mapIt(it[0].value) == @["first"])
  check(toSeq(whatsits.items).mapIt(it[0].value) == @["second"])
  check(toSeq(whosits.items).mapIt(it[0].value) == @["third"])
  check(toSeq(whysit.items).mapIt(it[0].value) == @["fourth"])
  check(toSeq(whensit.items).mapIt(it[0].value) == @["fifth"])

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.
  necsus(
    runner,
    [~spawn1, ~spawn2, ~spawn3, ~spawn4, ~spawn5, ~assertion],
    conf = newNecsusConf(),
  )
.}

test "Spawning against aliased types should remain distinct":
  myApp()
