import macros, strutils, tables
import directiveSet, monoDirective, nimNode, commonVars, systemGen
import ../util/mailbox, ../runtime/[inbox, directives]

proc eventStorageIdent(event: MonoDirective | NimNode): NimNode =
    ## Returns the name of the identifier that holds the storage for an event
    when event is NimNode: ident(event.symbols.join("_") & "_storage")
    elif event is MonoDirective: eventStorageIdent(event.argType)

proc inboxFields(name: string, dir: MonoDirective): seq[WorldField] = @[
    (dir.eventStorageIdent.strVal, nnkBracketExpr.newTree(bindSym("Mailbox"), dir.argType)),
    (name, nnkBracketExpr.newTree(bindSym("Inbox"), dir.argType))
]

proc generateInbox(details: GenerateContext, arg: SystemArg, name: string, inbox: MonoDirective): NimNode =
    case details.hook
    of Early:
        let storageIdent = inbox.eventStorageIdent
        let inboxName = name.ident
        let eventType = inbox.argType
        return quote:
            `appStateIdent`.`storageIdent` = newMailbox[`eventType`](`appStateIdent`.`confIdent`.eventQueueSize)
            `appStateIdent`.`inboxName` = newInbox[`eventType`](`appStateIdent`.`storageIdent`)
    of LoopEnd:
        let eventStore = inbox.eventStorageIdent
        return quote:
            clear(`appStateIdent`.`eventStore`)
    else:
        return newEmptyNode()

let inboxGenerator* {.compileTime.} = newGenerator(
    ident = "Inbox",
    generate = generateInbox,
    worldFields = inboxFields,
)

proc hasInboxes(details: GenerateContext, outbox: MonoDirective): bool =
    ## Returns whether an outbox has anyone that cares about the messages it sends
    if inboxGenerator in details.directives:
        for _, directive in details.directives[inboxGenerator]:
            if directive.monoDir.argType == outbox.argType:
                return true
    return false

proc outboxFields(name: string, dir: MonoDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("Outbox"), dir.argType)) ]

proc generateOutbox(details: GenerateContext, arg: SystemArg, name: string, outbox: MonoDirective): NimNode =
    case details.hook
    of Standard:
        let event = "event".ident
        let procName = name.ident
        let eventType = outbox.argType
        let storageIdent = outbox.eventStorageIdent

        # If there is nobody to listen to this event, just discard it immediately
        let body = if details.hasInboxes(outbox):
            quote:
                send[`eventType`](`appStateIdent`.`storageIdent`, `event`)
        else:
            quote:
                discard

        return quote:
            `appStateIdent`.`procName` = proc(`event`: sink `eventType`) = `body`
    else:
        return newEmptyNode()

let outboxGenerator* {.compileTime.} = newGenerator(
    ident = "Outbox", 
    generate = generateOutbox,
    worldFields = outboxFields,
)