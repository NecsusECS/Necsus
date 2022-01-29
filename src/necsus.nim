import necsus / runtime / [entity, query, world, systemVar]
import necsus / compiletime / [
    parse, codegen, codeGenInfo, queryGen, spawnGen, tickGen,
    necsusConf, detachGen, sysVarGen, lookupGen
]
import sequtils, macros, options

export entity, query, world, necsusConf, systemVar

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

macro necsus*(
    runner: typed{sym},
    startupSystems: openarray[SystemFlag],
    systems: openarray[SystemFlag],
    conf: NecsusConf,
    pragmaProc: untyped
) =
    ## Creates an ECS world

    let parsedSystems = concat(
        startupSystems.parseSystemList(isStartup = true),
        systems.parseSystemList(isStartup = false)
    )

    let parsedApp = parseApp(pragmaProc, runner)

    let name = pragmaProc.name
    let codeGenInfo = newCodeGenInfo(name, conf, parsedApp, parsedSystems)

    result = newStmtList(
        codeGenInfo.components.createComponentEnum,
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
        codeGenInfo.createTickRunner(runner)
    )

    when defined(dump):
        echo result.repr
