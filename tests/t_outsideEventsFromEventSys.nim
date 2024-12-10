import unittest, necsus

type
    SomeEvent = int
    OtherEvent = int

var expect = 0

proc receive(msg: SomeEvent) {.eventSys.} =
    check(msg == expect)
    expect += 1

proc receive2(msg: OtherEvent, send: Outbox[string]) {.eventSys.} =
    check(msg == expect)
    expect += 1

proc testEvents() {.necsus([~receive, ~receive2], newNecsusConf()), used.}

test "Sending events in from the outside world":
    var instance: testEventsState
    instance.initTestEvents()

    instance.sendSomeEvent(0)
    instance.sendSomeEvent(1)

    instance.sendOtherEvent(2)
    instance.tick()

    instance.sendOtherEvent(3)
    instance.tick()

    check(expect == 4)
