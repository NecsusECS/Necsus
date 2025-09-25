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

  proc systemName(values: Inbox[OpenSymbol[T]]) {.depends(sendOne, sendTwo).} =
    check(values.toSeq == @[(A, 1), (B, 2), (C, 3)])

buildTestSystems(testSystem, SomeEnum)

proc buildSend[T](): auto =
  return proc(trigger: Outbox[OpenSymbol[T]]) =
    trigger((A, 1))

let externalSend = buildSend[SomeEnum]()

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~externalSend, ~testSystem], newNecsusConf()).}

test "Creating an eventing system that uses open symbols":
  myApp()
