import macros, strutils, tables, sequtils
import directiveSet, monoDirective, nimNode, commonVars, systemGen
import ../runtime/[mailbox, directives]

proc eventStorageIdent(event: MonoDirective | NimNode): NimNode =
    ## Returns the name of the identifier that holds the storage for an event
    when event is NimNode: ident(event.symbols.join("_") & "_storage")
    elif event is MonoDirective: eventStorageIdent(event.argType)

proc getSignature(node: NimNode): string =
    case node.kind
    of nnkSym: return node.signatureHash
    of nnkBracketExpr: return node.children.toSeq.mapIt(it.getSignature).join()
    else: node.expectKind({nnkSym})

proc chooseInboxName(context, argName: NimNode, local: MonoDirective): string =
    let signature = if argName.kind == nnkSym: argName.getSignature else: context.getSignature
    return signature & argName.strVal

proc inboxFields(name: string, dir: MonoDirective): seq[WorldField] = @[
    (name, nnkBracketExpr.newTree(bindSym("Mailbox"), dir.argType))
]

proc inboxSystemArg(name: string, dir: MonoDirective): NimNode =
    let storageIdent = name.ident
    let eventType = dir.argType
    return quote:
        Inbox[`eventType`](addr `appStateIdent`.`storageIdent`)

proc generateInbox(details: GenerateContext, arg: SystemArg, name: string, inbox: MonoDirective): NimNode =
    case details.hook
    of AfterActiveCheck:
        let eventStore = name.ident
        return quote:
            clear(`appStateIdent`.`eventStore`)
    else:
        return newEmptyNode()

let inboxGenerator* {.compileTime.} = newGenerator(
    ident = "Inbox",
    interest = { Early, AfterActiveCheck },
    chooseName = chooseInboxName,
    generate = generateInbox,
    worldFields = inboxFields,
    systemArg = inboxSystemArg,
)

iterator inboxes(details: GenerateContext, outbox: MonoDirective): SystemArg =
    ## Yields the inboxes an outbox should write to
    if inboxGenerator in details.directives:
        for _, sysArg in details.directives[inboxGenerator]:
            if sysArg.monoDir.argType == outbox.argType:
                yield sysArg

proc outboxFields(name: string, dir: MonoDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("Outbox"), dir.argType)) ]

proc generateOutbox(details: GenerateContext, arg: SystemArg, name: string, outbox: MonoDirective): NimNode =
    case details.hook
    of Standard:
        let event = "event".ident
        let procName = name.ident
        let eventType = outbox.argType

        var body = newStmtList()
        for sysArg in inboxes(details, outbox):
            let inboxIdent = details.nameOf(sysArg).ident
            body.add quote do:
                send[`eventType`](`appStateIdent`.`inboxIdent`, `event`)

        return quote:
            `appStateIdent`.`procName` = proc(`event`: sink `eventType`) = `body`
    else:
        return newEmptyNode()

let outboxGenerator* {.compileTime.} = newGenerator(
    ident = "Outbox",
    interest = { Standard },
    generate = generateOutbox,
    worldFields = outboxFields,
)