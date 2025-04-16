import unittest, necsus

type A = object

proc system(bundle: Bundle[A]) =
  discard

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~system], conf = newNecsusConf()).}

test "Bundles that reference empty objects should compile":
  myApp()
