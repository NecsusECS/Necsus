import necsus / runtime / [ entityId, query, systemVar, inbox, directives, necsusConf, spawn, pragmas ]
import necsus / compiletime / [ parse, systemGen, codeGenInfo, worldGen, worldEnum, tickGen, commonVars ]

import sequtils, macros, options

when defined(dump):
    import strutils

export entityId, query, query.items, necsusConf, systemVar, inbox, directives, spawn, pragmas

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
    startup: NimNode,
    systems: NimNode,
    teardown: NimNode,
    conf: NimNode,
    pragmaProc: NimNode
): NimNode =
    ## Creates an ECS world

    let parsedApp = parseApp(pragmaProc, runner)

    let codeGenInfo = when not defined(nimsuggest):
        let parsedSystems = concat(
            parseSystemList(startup, StartupPhase),
            parseSystemList(systems, LoopPhase),
            parseSystemList(teardown, TeardownPhase)
        )
        newCodeGenInfo(conf, parsedApp, parsedSystems)
    else:
        newEmptyCodeGenInfo(conf, parsedApp)

    result = newStmtList(
        codeGenInfo.archetypeEnum.codeGen,
        codeGenInfo.createAppStateType(),
        codeGenInfo.createAppStateDestructor(),
        codeGenInfo.generateForHook(GenerateHook.Outside),
        codeGenInfo.createAppStateInit(),
        codeGenInfo.createTickProc(),
        pragmaProc
    )

    pragmaProc.body = when not defined(nimsuggest):
        newStmtList(
            codeGenInfo.createAppStateInstance(),
            codeGenInfo.createTickRunner(runner),
            codeGenInfo.createAppReturn(pragmaProc),
        )
    else:
        newStmtList()

    when defined(dump):
        echo "import necsus/runtime/[world, archetypeStore], std/math, necsus/util/profile"
        echo "const DEFAULT_ENTITY_COUNT = 1_000"
        echo replace(result.repr, "proc =destroy", "proc `=destroy`")

macro necsus*(
    runner: typed{sym},
    startup: openarray[SystemFlag],
    systems: openarray[SystemFlag],
    teardown: openarray[SystemFlag],
    conf: NecsusConf,
    pragmaProc: untyped
) =
    ## Creates an ECS world
    buildApp(runner, startup, systems, teardown, conf, pragmaProc)

macro necsus*(
    startup: openarray[SystemFlag],
    systems: openarray[SystemFlag],
    teardown: openarray[SystemFlag],
    conf: NecsusConf,
    pragmaProc: untyped
) =
    ## Creates an ECS world
    buildApp(bindSym("gameLoop"), startup, systems, teardown, conf, pragmaProc)

macro runSystemOnce*(systemDef: typed): untyped =
    ## Creates a single system and immediately executes it with a specific set of directives

    let systemIdent = genSym()
    let system = parseSystemDef(systemIdent, systemDef, LoopPhase)

    let necsusConfIdent = genSym()
    let defineConf = quote do:
        let `necsusConfIdent` = newNecsusConf()

    let app = newEmptyApp(genSym().strVal)
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
