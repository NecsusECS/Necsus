import macros, strutils, codeGenInfo, sequtils, directiveSet, monoDirective, nimNode, necsusUtil/packedList

proc eventStorageIdent(event: InboxDef | OutboxDef | NimNode): NimNode =
    ## Returns the name of the identifier that holds the storage for an event
    when event is NimNode: ident(event.symbols.join("_") & "_storage")
    elif event is OutboxDef: eventStorageIdent(event.argType)
    elif event is InboxDef: eventStorageIdent(event.argType)

proc createInboxProc(name: string, inbox: InboxDef): NimNode =
    ## Creates the proc for receiving messages
    let storageIdent = inbox.eventStorageIdent
    let inboxName = name.ident
    let eventType = inbox.argType
    result = quote:
        var `storageIdent` = newPackedList[`eventType`](`confIdent`.eventQueueSize)
        let `inboxName` = newInbox[`eventType`](`storageIdent`)

proc hasInboxes(codeGenInfo: CodeGenInfo, outbox: OutboxDef): bool =
    ## Returns whether an outbox has anyone that cares about the messages it sends
    codeGenInfo.inboxes.anyIt(it.value.argType == outbox.argType)

proc createOutboxProc(codeGenInfo: CodeGenInfo, name: string, outbox: OutboxDef): NimNode =
    ## Creates the proc for sending messages
    let event = "event".ident
    let procName = name.ident
    let eventType = outbox.argType
    let storageIdent = outbox.eventStorageIdent

    # If there is nobody to listen to this event, just discard it immediately
    let body = if codeGenInfo.hasInboxes(outbox):
        quote:
            discard push[`eventType`](`storageIdent`, `event`)
    else:
        quote:
            discard

    result = quote:
        proc `procName`(`event`: sink `eventType`) = `body`

proc createEventDeclarations*(codeGenInfo: CodeGenInfo): NimNode =
    ## Creates declarations for handling events
    result = newStmtList()

    for (name, inbox) in codeGenInfo.inboxes:
        result.add(createInboxProc(name, inbox))

    for (name, outbox) in codeGenInfo.outboxes:
        result.add(codeGenInfo.createOutboxProc(name, outbox))

proc createEventResets*(codeGenInfo: CodeGenInfo): NimNode =
    ## Creates code for clearing any events out of inboxes
    result = newStmtList()
    for (_, event) in codeGenInfo.outboxes:
        if codeGenInfo.hasInboxes(event):
            let eventStore = event.eventStorageIdent
            result.add quote do:
                clear(`eventStore`)
