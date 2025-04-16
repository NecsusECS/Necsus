import unittest, necsus

type A[T] = object
  value: Shared[T]

proc setValue(bundle: Bundle[A[string]]) =
  bundle.value := "foo"

proc verify(bundle: Bundle[A[string]]) =
  check(bundle.value.getOrRaise == "foo")

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~setValue, ~verify], conf = newNecsusConf()).}

test "Bundles with generic parameters should compile":
  myApp()
