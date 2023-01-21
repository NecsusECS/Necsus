import macros, strutils, tables
import directiveSet, monoDirective, nimNode, ../util/mailbox, commonVars, systemGen

proc eventStorageIdent(event: MonoDirective | NimNode): NimNode =
    ## Returns the name of the identifier that holds the storage for an event
    when event is NimNode: ident(event.symbols.join("_") & "_storage")
    elif event is MonoDirective: eventStorageIdent(event.argType)

proc parseInbox(argName: string, component: NimNode): MonoDirective = newInboxDef(component)

proc generateInbox(details: GenerateContext, inbox: MonoDirective): NimNode =
    case details.hook
    of Early:
        let storageIdent = inbox.eventStorageIdent
        let inboxName = details.name.ident
        let eventType = inbox.argType
        return quote:
            var `storageIdent` = newMailbox[`eventType`](`confIdent`.eventQueueSize)
            let `inboxName` = newInbox[`eventType`](`storageIdent`)
    of LoopEnd:
        let eventStore = inbox.eventStorageIdent
        return quote:
            clear(`eventStore`)
    else:
        return newEmptyNode()

let inboxGenerator* {.compileTime.} = newGenerator("Inbox", parseInbox, generateInbox)

proc hasInboxes(details: GenerateContext, outbox: MonoDirective): bool =
    ## Returns whether an outbox has anyone that cares about the messages it sends
    for _, directive in details.directives[inboxGenerator]:
        if directive.monoDir.argType == outbox.argType:
            return true
    return false

proc parseOutbox(argName: string, component: NimNode): MonoDirective = newOutboxDef(component)

proc generateOutbox(details: GenerateContext, outbox: MonoDirective): NimNode =
    case details.hook
    of Standard:
        let event = "event".ident
        let procName = details.name.ident
        let eventType = outbox.argType
        let storageIdent = outbox.eventStorageIdent

        # If there is nobody to listen to this event, just discard it immediately
        let body = if details.hasInboxes(outbox):
            quote:
                send[`eventType`](`storageIdent`, `event`)
        else:
            quote:
                discard

        return quote:
            proc `procName`(`event`: sink `eventType`) = `body`
    else:
        return newEmptyNode()

let outboxGenerator* {.compileTime.} = newGenerator("Outbox", parseOutbox, generateOutbox)