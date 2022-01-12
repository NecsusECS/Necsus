import necsus / [entity, query, world, parse, codegen, componentSet, directive, directiveSet, componentDef]
export entity, query, world

import sequtils, macros

macro necsus*(
    runner: typed{sym},
    startupSystems: typed,
    systems: typed,
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

    let execSystems = callSystems(parsed.filterIt(not it.isStartup), allComponents, allSpawns, allQueries)

    pragmaProc.body = newStmtList(
        allComponents.createComponentEnum,
        allComponents.createComponentObj,
        allComponents.createQueryObj(allQueries),
        createWorldInstance(allComponents, allQueries),
        createQueryVars(allComponents, allQueries),
        createSpawnFunc(allComponents, allSpawns, allQueries),
        callSystems(parsed.filterIt(it.isStartup), allComponents, allSpawns, allQueries),
        newCall(runner, execSystems)
    )

    result = pragmaProc
    echo result.repr


