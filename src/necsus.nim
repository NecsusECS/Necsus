##
## Necsus: An ECS (entity component system) for Nim
##
## In depth documentation can be found here:
##
## * https://necsusecs.github.io/Necsus/
##

import necsus / runtime / [ entityId, query, systemVar, mailbox, directives, necsusConf, spawn, pragmas ]
import necsus / compiletime / [ parse, systemGen, codeGenInfo, worldGen, archetype ]
import necsus / compiletime / [ worldEnum, tickGen, commonVars, marshalGen ]
import sequtils, macros, options

when defined(dump):
    import necsus/util/dump

export entityId, query, query.items, necsusConf, systemVar, mailbox, directives, spawn, pragmas

type
    SystemFlag* = object
        ## Fixes type checking errors when passing system procs into the necsus macro

    NecsusRun* = enum
        ## For the default game loop runner, tells the loop when to exit
        RunLoop, ExitLoop

proc `~`*(system: proc): SystemFlag = SystemFlag()
    ## Ensures that system macros with various arguments are able to be massed in to the necsus macro

proc gameLoop*(exit: Shared[NecsusRun], tick: proc(): void) =
    ## A standard game loop runner
    while exit.get(RunLoop) == RunLoop:
        tick()

proc buildApp(
    runner: NimNode,
    systems: NimNode,
    conf: NimNode,
    pragmaProc: NimNode
): NimNode =
    ## Creates an ECS world

    let parsedApp = parseApp(pragmaProc, runner)
    let parsedSystems = parseSystemList(systems)

    let codeGenInfo = newCodeGenInfo(conf, parsedApp, parsedSystems)

    result = newStmtList(
        codeGenInfo.archetypeEnum.codeGen,
        codeGenInfo.createAppStateType(),
        codeGenInfo.createAppStateDestructor(),
        codeGenInfo.createMarshalProcs(),
        codeGenInfo.createSendProcs(),
        codeGenInfo.generateForHook(GenerateHook.Outside),
        codeGenInfo.createAppStateInit(),
        codeGenInfo.createTickProc(),
        pragmaProc
    )

    pragmaProc.body = newStmtList(
        codeGenInfo.createAppStateInstance(),
        codeGenInfo.createTickRunner(runner),
        codeGenInfo.createAppReturn(pragmaProc),
    )

    when defined(archetypes):
        codeGenInfo.archetypes.dumpAnalysis

    when defined(dump):
        result.dumpGeneratedCode(parsedApp, parsedSystems)

macro necsus*(
    runner: typed{sym},
    systems: openarray[SystemFlag],
    conf: NecsusConf,
    pragmaProc: untyped
) =
    ## Creates an ECS world
    buildApp(runner, systems, conf, pragmaProc)

macro necsus*(
    systems: openarray[SystemFlag],
    conf: NecsusConf,
    pragmaProc: untyped
) =
    ## Creates an ECS world
    buildApp(bindSym("gameLoop"), systems, conf, pragmaProc)

macro runSystemOnce*(systemDef: typed): untyped =
    ## Creates a single system and immediately executes it with a specific set of directives

    let systemIdent = genSym()
    let system = parseSystemDef(systemIdent, systemDef)

    let necsusConfIdent = genSym()
    let defineConf = quote do:
        let `necsusConfIdent` = newNecsusConf()

    let app = newEmptyApp("App_" & $lineInfoObj(systemDef).line & "_" & $lineInfoObj(systemDef).column)
    let codeGenInfo = newCodeGenInfo(necsusConfIdent, app, @[ system ])
    let initIdent = codeGenInfo.appStateInit

    let call = newCall(systemIdent, system.args.mapIt(systemArg(codeGenInfo, it)))

    return newStmtList(
        codeGenInfo.archetypeEnum.codeGen,
        codeGenInfo.createAppStateType(),
        codeGenInfo.createAppStateDestructor(),
        codeGenInfo.generateForHook(GenerateHook.Outside),
        defineConf,
        codeGenInfo.createAppStateInit(),
        quote do:
            block:
                let `appStateIdent` = `initIdent`()
                let `systemIdent` = `systemDef`
                `call`
    )
