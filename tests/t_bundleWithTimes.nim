import unittest, necsus, os

type A = object
  delta: TimeDelta
  elapsed: TimeElapsed

var lastElapsed = -1.0
var lastDelta = -1.0
var timesThrough = 1

proc assertion*(bundle: Bundle[A]) =
  check(bundle.elapsed() > lastElapsed)
  check(bundle.delta() > lastDelta)

  lastElapsed = bundle.elapsed()

  sleep(timesThrough * 10)
  timesThrough += 1

proc runner(tick: proc(): void) =
  tick()
  tick()
  tick()

proc myApp() {.necsus(runner, [~assertion], conf = newNecsusConf()).}

test "Bundles that contain time references":
  myApp()
