import necsus / runtime / [entity, query, world]
import necsus / compiletime / [parse, codegen, componentSet, directive, directiveSet, componentDef]
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

    let allComponents = parsed.componentSet(name.strVal)

    let allQueries = newDirectiveSet[QueryDef](name.strVal, parsed.queries.toSeq)

    let allSpawns = newDirectiveSet[SpawnDef](name.strVal, parsed.spawns.toSeq)

    let allUpdates = newDirectiveSet[UpdateDef](name.strVal, parsed.updates.toSeq)

    let execSystems = callSystems(parsed.filterIt(not it.isStartup), allComponents, allSpawns, allQueries, allUpdates)

    result = newStmtList(
        allComponents.createComponentEnum,
        allComponents.createComponentObj,
        allComponents.createQueryObj(allQueries),
        pragmaProc
    )

    pragmaProc.body = newStmtList(
        createWorldInstance(initialSize.intVal, allComponents, allQueries),
        createQueryVars(allComponents, allQueries),
        createSpawnFunc(allComponents, allSpawns, allQueries),
        createUpdateProcs(allComponents, allUpdates, allQueries),
        callSystems(parsed.filterIt(it.isStartup), allComponents, allSpawns, allQueries, allUpdates),
        newCall(runner, execSystems)
    )

    # echo result.repr


