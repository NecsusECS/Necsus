import unittest, necsus

var value: seq[string]

proc systemA(send: Outbox[string]) =
  send("foo")

proc systemB(system: RegisterEventSystem[string]) {.startupSys.} =
  system do(event: string) -> void:
    check event == "foo"
    value.add("bar")

proc systemC(
    system: RegisterEventSystem[string], two: RegisterEventSystem[string]
) {.startupSys.} =
  system do(event: string) -> void:
    check event == "foo"
    value.add("baz")

  two do(event: string) -> void:
    check event == "foo"
    value.add("qux")

proc runner(tick: proc(): void) =
  tick()

proc app() {.necsus(runner, [~systemA, ~systemB, ~systemC], newNecsusConf()).}

test "RegisterEventSystems should all have their own storage":
  app()
  check "bar" in value
  check "baz" in value
  check "qux" in value
