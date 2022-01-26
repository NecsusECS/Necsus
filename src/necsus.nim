import necsus / runtime / [entity, query, world]
import necsus / compiletime / [ parse, codegen, componentSet, codeGenInfo, queryGen, spawnGen, tickGen, necsusConf ]
import sequtils, macros

export entity, query, world, necsusConf

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
    let codeGenInfo = newCodeGenInfo(name, conf, parsed)
    let allComponents = parsed.componentSet(name.strVal)

    result = newStmtList(
        allComponents.createComponentEnum,
        allComponents.createComponentObj,
        pragmaProc
    )

    pragmaProc.body = newStmtList(
        codeGenInfo.createConfig(),
        codeGenInfo.createWorldInstance(),
        codeGenInfo.createComponentInstance(),
        codeGenInfo.createQueries(),
        codeGenInfo.createSpawns(),
        codeGenInfo.createUpdates(),
        createDeleteProc(),
        codeGenInfo.createTickRunner(runner)
    )

    when defined(dump):
        echo result.repr
