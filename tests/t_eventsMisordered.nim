import unittest, necsus, sequtils

var timesThrough = 0

proc receive1(receive: Inbox[int]) =
  case timesThrough
  of 0:
    check(receive.items.toSeq == newSeq[int]())
  of 1:
    check(receive.items.toSeq == @[0, 50])
  of 2:
    check(receive.items.toSeq == @[1, 51])
  else:
    assert(false)

proc publish1(send: Outbox[int]) =
  send(timesThrough)

proc receive2(receive: Inbox[int]) =
  case timesThrough
  of 0:
    check(receive.items.toSeq == @[0])
  of 1:
    check(receive.items.toSeq == @[50, 1])
  of 2:
    check(receive.items.toSeq == @[51, 2])
  else:
    assert(false)

proc publish2(send: Outbox[int]) =
  send(timesThrough + 50)

proc runner(tick: proc(): void) =
  tick()
  timesThrough += 1
  tick()
  timesThrough += 1
  tick()

proc testEvents() {.
  necsus(runner, [~receive1, ~publish1, ~receive2, ~publish2], newNecsusConf())
.}

test "Inboxes should only be cleared after a system has executed":
  testEvents()
