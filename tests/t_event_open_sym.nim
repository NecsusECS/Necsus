import necsus, std/[unittest, sequtils]

type
  SomeEnum = enum
    A
    B
    C

  OpenSymbol[T] = tuple[kind: T, state: int]

  SendBundle[T] = object
    send: Outbox[OpenSymbol[T]]

template buildTestSystems*(systemName: untyped, T: typedesc[enum]) =
  proc sendOne(trigger: Bundle[SendBundle[T]]) =
    trigger.send((B, 2))

  proc sendTwo(trigger: Outbox[OpenSymbol[T]]) =
    trigger((C, 3))

  proc receive(value: OpenSymbol[T], eventSysCalled: Shared[bool]) {.eventSys.} =
    eventSysCalled := true

  proc systemName(values: Inbox[OpenSymbol[T]]) {.depends(sendOne, sendTwo, receive).} =
    check(values.toSeq == @[(A, 1), (B, 2), (C, 3)])

buildTestSystems(testSystem, SomeEnum)

proc buildSend[T](): auto =
  return proc(trigger: Outbox[OpenSymbol[T]]) =
    trigger((A, 1))

let externalSend = buildSend[SomeEnum]()

proc runner(eventSysCalled: Shared[bool], tick: proc(): void) =
  tick()
  check eventSysCalled.get()

proc myApp() {.necsus(runner, [~externalSend, ~testSystem], newNecsusConf()).}

test "Creating an eventing system that uses open symbols":
  myApp()
