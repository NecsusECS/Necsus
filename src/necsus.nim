import necsus / runtime / [entity, query, world]
import necsus / compiletime / [ parse, codegen, componentSet, codeGenInfo, queryGen, spawnGen, tickGen ]
import sequtils, macros

export entity, query, world

type SystemFlag* = object
    ## Fixes type checking errors when passing system procs into the necsus macro

proc `~`*(system: proc): SystemFlag = SystemFlag()
    ## Ensures that system macros with various arguments are able to be massed in to the necsus macro

macro necsus*(
    runner: typed{sym},
    startupSystems: openarray[SystemFlag],
    systems: openarray[SystemFlag],
    initialSize: int,
    pragmaProc: untyped
) =
    ## Creates an ECS world

    let parsed = concat(
        startupSystems.parseSystemList(isStartup = true),
        systems.parseSystemList(isStartup = false)
    )

    pragmaProc.expectKind(nnkProcDef)

    let name = pragmaProc.name
    let codeGenInfo = newCodeGenInfo(name, initialSize, parsed)
    let allComponents = parsed.componentSet(name.strVal)

    result = newStmtList(
        allComponents.createComponentEnum,
        allComponents.createComponentObj,
        pragmaProc
    )

    pragmaProc.body = newStmtList(
        createWorldInstance(initialSize, allComponents),
        codeGenInfo.createComponentInstance(),
        codeGenInfo.createQueries(),
        codeGenInfo.createSpawns(),
        codeGenInfo.createUpdates(),
        createDeleteProc(),
        codeGenInfo.createTickRunner(runner)
    )

    # echo result.repr
