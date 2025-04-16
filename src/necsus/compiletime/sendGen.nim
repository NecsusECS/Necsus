import std/[macros, tables, sets]
import tools, codeGenInfo, common, systemGen, tickGen, parse, eventGen, monoDirective
import ../runtime/[world]

proc addEventDirectives(arg: NimNode, into: var seq[MonoDirective]) =
  ## Recursively adds event directives to the given sequence
  case arg.kind
  of nnkInfix:
    if arg[0].strVal == "or":
      for child in arg[1 ..^ 1]:
        child.addEventDirectives(into)
      return
  else:
    into.add(newMonoDir(arg))
    return

  error("Unsupported event type: " & arg.repr, arg)

proc eventCallbackDirectives(system: ParsedSystem): seq[MonoDirective] =
  ## Yields the events that can be handled by an event callback system
  system.prefixArgs[0].expectKind(nnkIdentDefs)
  system.callbackSysType.addEventDirectives(result)

proc eventCallbackAccepts(systemType, eventType: NimNode): bool =
  ## Returns whether a given system type accepts a specific event
  case systemType.kind
  of nnkInfix:
    if systemType[0].strVal == "or":
      for child in systemType[1 ..^ 1]:
        if child.eventCallbackAccepts(eventType):
          return true
  else:
    return systemType == eventType

proc mailboxIndex(
    details: CodeGenInfo
): Table[MonoDirective, seq[(ParsedSystem, NimNode)]] =
  ## Creates a table of all inboxes keyed on the type of message they receive
  result = initTable[MonoDirective, seq[(ParsedSystem, NimNode)]](64)
  for system in details.systems:
    for arg in system.allArgs:
      if arg.generator == inboxGenerator:
        result.mgetOrPut(arg.monoDir, newSeq[(ParsedSystem, NimNode)]()).add(
          (system, details.nameOf(arg).ident)
        )
      elif arg.generator == outboxGenerator:
        # Store any outboxes to ensure the public send procs get created
        discard result.mgetOrPut(arg.monoDir, newSeq[(ParsedSystem, NimNode)]())

    if system.phase in {EventCallback, IndirectEventCallback}:
      system.prefixArgs[0].expectKind(nnkIdentDefs)
      for directive in system.eventCallbackDirectives():
        result.mgetOrPut(directive, newSeq[(ParsedSystem, NimNode)]()).add(
          (system, newEmptyNode())
        )

let event {.compileTime.} = ident("event")

proc genAddToInbox(
    details: CodeGenInfo,
    system: ParsedSystem,
    eventType, inboxIdent: NimNode,
    seen: var HashSet[string],
): NimNode =
  ## Generates code for adding an event to an inbox
  if inboxIdent.strVal notin seen:
    seen.incl(inboxIdent.strVal)
    let addStmt = quote:
      add[`eventType`](`appStateIdent`.`inboxIdent`, `event`)
    return addStmt.addActiveChecks(details, system.checks, EventCallback)
  else:
    return newStmtList()

proc initIndirectEventInboxes*(details: CodeGenInfo): NimNode =
  ## Generates the code for initializing indirect inboxes
  result = newStmtList()
  for system in details.systems:
    if system.phase == IndirectEventCallback:
      result.add(system.callbackSysMailboxName.initInbox(system.callbackSysType))

proc createSendProcs*(details: CodeGenInfo): NimNode =
  ## Generates a set of procs needed to send messages
  result = newStmtList()
  let appStateType = details.appStateTypeName

  for directive, inboxes in details.mailboxIndex:
    let (internalName, externalName) = directive.sendEventProcName
    let eventType = directive.argType

    var body = newStmtList(emitEventTrace("Event ", directive.name, ": ", `event`))

    var seen = initHashSet[string]()

    if not isFastCompileMode(fastEvents):
      for (system, inboxIdent) in inboxes:
        if inboxIdent.kind != nnkEmpty:
          body.add details.genAddToInbox(system, eventType, inboxIdent, seen)

      for system in details.systems:
        case system.phase
        of EventCallback:
          if system.callbackSysType.eventCallbackAccepts(eventType):
            body.add(details.invokeSystem(system, {EventCallback}, [event]))
        of IndirectEventCallback:
          if system.callbackSysType.eventCallbackAccepts(eventType):
            body.add details.genAddToInbox(
              system, eventType, system.callbackSysMailboxName, seen
            )
        else:
          discard

      if body.len == 0:
        body.add(nnkDiscardStmt.newTree(newEmptyNode()))

      result.add quote do:
        proc `internalName`(
            `appStateIdent`: pointer, `event`: `eventType`
        ) {.used, nimcall.} =
          let `appStateIdent` {.used.} = cast[ptr `appStateType`](`appStateIdent`)
          `body`

        proc `externalName`(
            `appStateIdent`: var `appStateType`, `event`: `eventType`
        ) {.used, nimcall.} =
          `internalName`(addr `appStateIdent`, `event`)

    else:
      result.add quote do:
        proc `externalName`(
            `appStateIdent`: var `appStateType`, `event`: `eventType`
        ) {.used, nimcall.} =
          discard
