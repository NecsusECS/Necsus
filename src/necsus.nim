import necsus / runtime / [entity, query, world, systemVar]
import necsus / compiletime / [
    parse, codegen, componentSet, codeGenInfo, queryGen, spawnGen, tickGen,
    necsusConf, detachGen, sysVarGen, lookupGen
]
import sequtils, macros

export entity, query, world, necsusConf, systemVar

type SystemFlag* = object
    ## Fixes type checking errors when passing system procs into the necsus macro

proc `~`*(system: proc): SystemFlag = SystemFlag()
    ## Ensures that system macros with various arguments are able to be massed in to the necsus macro

macro necsus*(
    runner: typed{sym},
    startupSystems: openarray[SystemFlag],
    systems: openarray[SystemFlag],
    conf: NecsusConf,
    pragmaProc: untyped
) =
    ## Creates an ECS world

    let parsed = concat(
        startupSystems.parseSystemList(isStartup = true),
        systems.parseSystemList(isStartup = false)
    )

    pragmaProc.expectKind(nnkProcDef)

    let name = pragmaProc.name
    let codeGenInfo = newCodeGenInfo(name, conf, parseApp(pragmaProc), parsed)
    let allComponents = parsed.componentSet(name.strVal)

    result = newStmtList(
        allComponents.createComponentEnum,
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
