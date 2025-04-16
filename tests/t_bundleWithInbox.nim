import unittest, necsus, sequtils

type A = object
  events: Inbox[string]

proc setup*(send: Outbox[string]) =
  send("foo")

proc assertion1*(bundle: Bundle[A]) =
  check(bundle.events.toSeq == @["foo"])

proc assertion2*(bundle: Bundle[A]) =
  check(bundle.events.len == 0)

proc runner(tick: proc(): void) =
  tick()
  tick()
  tick()

proc myApp() {.
  necsus(runner, [~setup, ~assertion1, ~assertion2], conf = newNecsusConf())
.}

test "Bundles that contain an inbox":
  myApp()
