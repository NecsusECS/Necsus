import unittest, necsus

type
    SomeEvent = int

var expect = 0

proc receive(msg: SomeEvent) {.eventSys.} =
    check(msg == expect)
    expect += 1

proc testEvents() {.necsus([~receive], newNecsusConf()), used.}

test "Sending events in from the outside world":
    var instance: testEventsState
    instance.initTestEvents()

    instance.sendSomeEvent(0)
    instance.sendSomeEvent(1)
    instance.sendSomeEvent(2)
    check(expect == 3)
