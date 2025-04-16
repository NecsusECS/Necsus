import unittest, necsus

type Controller = object
  data: Shared[string]

proc build(): auto =
  return proc(bundle: Bundle[Controller]) =
    bundle.data := "foo"

let logic = build()

proc assertion(bundle: Bundle[Controller]) =
  check(bundle.data == "foo")

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~logic, ~assertion], conf = newNecsusConf()).}

test "Bundles used with a constructed system":
  myApp()
