import necsus / runtime / [ entityId, query, systemVar, inbox, directives, necsusConf ]
import necsus / compiletime / [
    parse, codegen, codeGenInfo, queryGen, spawnGen, tickGen,
    detachGen, sysVarGen, lookupGen, eventGen, worldEnum
]
import sequtils, macros, options

export entityId, query, necsusConf, systemVar, inbox, directives

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

    let parsedSystems = concat(
        startup.parseSystemList(StartupPhase),
        systems.parseSystemList(LoopPhase),
        teardown.parseSystemList(TeardownPhase)
    )

    let parsedApp = parseApp(pragmaProc, runner)

    let name = pragmaProc.name
    let codeGenInfo = newCodeGenInfo(name, conf, parsedApp, parsedSystems)

    result = newStmtList(
        codeGenInfo.components.codeGen,
        codeGenInfo.queryEnum.codeGen,
        codeGenInfo.compGroupEnum.codeGen,
        pragmaProc
    )

    pragmaProc.body = newStmtList(
        codeGenInfo.createConfig(),
        codeGenInfo.createWorldInstance(),
        codeGenInfo.createComponentInstances(),
        codeGenInfo.createQueries(),
        codeGenInfo.createLookups(),
        codeGenInfo.createSpawns(),
        codeGenInfo.createAttaches(),
        codeGenInfo.createDetaches(),
        codeGenInfo.createDeleteProc(),
        codeGenInfo.createSharedVars(),
        codeGenInfo.createLocalVars(),
        codeGenInfo.createEventDeclarations(),
        codeGenInfo.createTickRunner(runner),
        codeGenInfo.createAppReturn(),
    )

    when defined(dump):
        echo result.repr

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
