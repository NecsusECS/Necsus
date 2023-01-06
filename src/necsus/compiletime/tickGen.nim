import macros, times, sequtils
import codeGenInfo, parse, directiveSet, tupleDirective, monoDirective, localDef, eventGen, commonVars

let timeDelta {.compileTime.} = ident("timeDelta")
let timeElapsed {.compileTime.} = ident("timeElapsed")

proc renderSystemArgs(codeGenInfo: CodeGenInfo, args: openarray[SystemArg]): seq[NimNode] =
    ## Renders system arguments down to nim code
    args.toSeq.map do (arg: SystemArg) -> NimNode:
        case arg.kind
        of SystemArgKind.Spawn:
            ident(codeGenInfo.spawns.nameOf(arg.spawn))
        of SystemArgKind.Query:
            ident(codeGenInfo.queries.nameOf(arg.query))
        of SystemArgKind.Attach:
            ident(codeGenInfo.attaches.nameOf(arg.attach))
        of SystemArgKind.Detach:
            ident(codeGenInfo.detaches.nameOf(arg.detach))
        of SystemArgKind.Lookup:
            ident(codeGenInfo.lookups.nameOf(arg.lookup))
        of SystemArgKind.TimeDelta:
            timeDelta
        of SystemArgKind.TimeElapsed:
            timeElapsed
        of SystemArgKind.Delete:
            deleteProc
        of SystemArgKind.Local:
            ident(codeGenInfo.locals.nameOf(arg.local))
        of SystemArgKind.Shared:
            ident(codeGenInfo.shared.nameOf(arg.shared))
        of SystemArgKind.Inbox:
            ident(codeGenInfo.inboxes.nameOf(arg.inbox))
        of SystemArgKind.Outbox:
            ident(codeGenInfo.outboxes.nameOf(arg.outbox))

proc callSystems(codeGenInfo: CodeGenInfo, systems: openarray[ParsedSystem]): NimNode =
    result = newStmtList()
    for system in systems:
        result.add(newCall(ident(system.symbol), codeGenInfo.renderSystemArgs(system.args)))

# proc createDelteFinalizers(codeGenInfo: CodeGenInfo): NimNode =
#     ## Creates method calls to process deleted entities
#     result = newStmtList()
#
#     # Delete entities out of components
#     for group in codeGenInfo.compGroups:
#         let storageIdent = group.componentStoreIdent
#         result.add quote do:
#             deleteComponents(`worldIdent`, `storageIdent`)

proc callTick(codeGenInfo: CodeGenInfo, runner: NimNode, body: NimNode): NimNode =
    ## Creates the code to invoke the runner
    var args = codeGenInfo.renderSystemArgs(codeGenInfo.app.runnerArgs)
    args.add(body)
    return newCall(runner, args)

proc createTickRunner*(codeGenInfo: CodeGenInfo, runner: NimNode): NimNode =
    ## Creates the code required to execute a single tick within the world

    let startups = codeGenInfo.callSystems(codeGenInfo.systems.filterIt(it.phase == StartupPhase))
    let loopSystems = codeGenInfo.callSystems(codeGenInfo.systems.filterIt(it.phase == LoopPhase))
    let teardown = codeGenInfo.callSystems(codeGenInfo.systems.filterIt(it.phase == TeardownPhase))
    let resetEvents = codeGenInfo.createEventResets()
    # let deleteFinalizers = codeGenInfo.createDelteFinalizers()
    let lastTime = ident("lastTime")
    let thisTime = ident("thisTime")
    let startTime = ident("startTime")
    let timeElapsed = ident("timeElapsed")

    let primaryLoop = codeGenInfo.callTick(
        runner,
        quote do:
            let `thisTime` = epochTime()
            `timeElapsed` = `thisTime` - `startTime`
            `timeDelta` = `thisTime` - `lastTime`
            `resetEvents`
            block:
                `loopSystems`
            `lastTime` = `thisTime`
    )

    result = quote do:
        let `startTime`: float = epochTime()
        var `timeElapsed`: float = 0
        var `lastTime`: float = `startTime`
        var `timeDelta`: float = 0
        `startups`
        `primaryLoop`
        `teardown`
