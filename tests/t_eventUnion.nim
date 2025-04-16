import unittest, necsus

type
  EventA = object
  EventB = object

proc publish(sendA: Outbox[EventA], sendB: Outbox[EventB]) =
  sendA(EventA())
  sendB(EventB())

proc receive(event: EventA or EventB, output: Shared[string]) {.eventSys.} =
  output := output.get() & $typeof(event)

proc assertions(output: Shared[string]) =
  check(output.get() == "EventAEventB")

proc runner(tick: proc(): void) =
  tick()

proc testEvents() {.necsus(runner, [~publish, ~receive, ~assertions], newNecsusConf()).}

test "Sending to a reciever that takes a union":
  testEvents()
