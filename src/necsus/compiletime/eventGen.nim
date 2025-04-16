import std/[macros, strutils, tables, sequtils]
import monoDirective, common, systemGen
import ../runtime/[inbox, directives]

proc getSignature(node: NimNode): string =
  case node.kind
  of nnkIdent:
    return node.strVal
  of nnkSym:
    return node.signatureHash
  of nnkBracketExpr:
    return node.children.toSeq.mapIt(it.getSignature).join()
  else:
    node.expectKind({nnkSym})

proc chooseInboxName(context, argName: NimNode, local: MonoDirective): string =
  context.getSignature & argName.getSignature

proc inboxFields(name: string, dir: MonoDirective): seq[WorldField] =
  @[(name, nnkBracketExpr.newTree(bindSym("seq"), dir.argType))]

proc inboxSystemArg(name: string, dir: MonoDirective): NimNode =
  let storageIdent = name.ident
  let eventType = dir.argType
  return quote:
    Inbox[`eventType`](addr `appStateIdent`.`storageIdent`)

proc initInbox*(name, typ: NimNode): NimNode =
  ## Creates the code for initializing an inbox
  return quote:
    `appStateIdent`.`name` = newSeqOfCap[`typ`](`appStateIdent`.config.inboxSize)

proc generateInbox(
    details: GenerateContext, arg: SystemArg, name: string, inbox: MonoDirective
): NimNode =
  let eventStore = name.ident
  case details.hook
  of Standard:
    return eventStore.initInbox(inbox.argType)
  of AfterActiveCheck:
    return quote:
      setLen(`appStateIdent`.`eventStore`, 0)
  else:
    return newEmptyNode()

let inboxGenerator* {.compileTime.} = newGenerator(
  ident = "Inbox",
  interest = {Standard, AfterActiveCheck},
  chooseName = chooseInboxName,
  generate = generateInbox,
  worldFields = inboxFields,
  systemArg = inboxSystemArg,
)

proc outboxFields(name: string, dir: MonoDirective): seq[WorldField] =
  @[(name, nnkBracketExpr.newTree(bindSym("Outbox"), dir.argType))]

proc generateOutbox(
    details: GenerateContext, arg: SystemArg, name: string, outbox: MonoDirective
): NimNode =
  case details.hook
  of Standard:
    let procName = name.ident
    let sendProc = outbox.sendEventProcName.internal
    return quote:
      `appStateIdent`.`procName` = newCallbackDir(`appStatePtr`, `sendProc`)
  else:
    return newEmptyNode()

let outboxGenerator* {.compileTime.} = newGenerator(
  ident = "Outbox",
  interest = {Standard},
  generate = generateOutbox,
  worldFields = outboxFields,
)
