import unittest, necsus

type SomeEvent = object
  value: int

var expect = 0

proc receive(receiver: Inbox[SomeEvent]) =
  check(receiver.len == expect.uint)

  for message in receiver:
    check(message.value == expect)

proc testEvents() {.necsus([~receive], newNecsusConf()), used.}

test "Sending events in from the outside world":
  var instance: testEventsState
  instance.initTestEvents()
  instance.tick()

  expect += 1
  instance.sendSomeEvent(SomeEvent(value: 1))
  instance.tick()

  expect += 1
  instance.sendSomeEvent(SomeEvent(value: 2))
  instance.sendSomeEvent(SomeEvent(value: 2))
  instance.tick()
