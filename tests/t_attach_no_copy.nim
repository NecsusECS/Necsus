when (NimMajor, NimMinor) >= (2, 2):
  import unittest, necsus, sequtils

  type
    Name = object
      name*: string

    Age = object
      age*: int

  proc `=copy`(a: var Age, b: Age) {.error.}

  proc execute(spawn: FullSpawn[(Name,)], addAge: Attach[(Age,)]) =
    let eid = spawn.with(Name(name: "Foo"))
    eid.addAge((Age(age: 20),))

  proc assertions(all: Query[(Name, ptr Age)]) =
    check(all.len == 1)
    for (name, age) in all:
      check(name.name == "Foo")
      check(age.age == 20)

  proc runner(tick: proc(): void) =
    tick()

  proc testAttaches() {.necsus(runner, [~execute, ~assertions], newNecsusConf()).}

  test "Attaching components without copying them":
    testAttaches()
