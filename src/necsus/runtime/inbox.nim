type
    SeqPtr[T] = ptr seq[T]

    Inbox*[T] = distinct SeqPtr[T]
        ## Receives events

    OutboxProc[T] = proc(appState: pointer, message: T): void {.fastcall.}

    Outbox*[T] = ref object
        ## Sends an event. Where `T` is the message being sent
        appState: pointer
        send: OutboxProc[T]

proc newOutbox*[T](appState: pointer, send: OutboxProc[T]): Outbox[T] {.inline.} =
    return Outbox[T](appState: appState, send: send)

proc send*[T](outbox: Outbox[T], message: sink T) {.inline.} =
    outbox.send(outbox.appState, message)

{.experimental: "callOperator".}
proc `()`*[T](outbox: Outbox[T], message: T) =
    ## Sends a message through an outbox
    outbox.send(outbox.appState, message)

iterator items*[T](inbox: Inbox[T]): lent T {.inline.} =
    ## Iterate over inbox items
    for message in items(SeqPtr[T](inbox)[]):
        yield message

proc len*[T](inbox: Inbox[T]): uint {.inline.} = SeqPtr[T](inbox)[].len.uint
    ## The number of events in this inbox