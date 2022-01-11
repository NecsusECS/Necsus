import necsus / [entity, query, world, parse, codegen, componentSet, directive, directiveSet, componentDef]
export entity, query, world

import sequtils, macros

macro necsus*(
    name: untyped{ident},
    runner: typed{sym},
    startupSystems: typed,
    systems: typed,
) =
    ## Creates an ECS world

    let parsed = concat(
        startupSystems.parseSystemList(isStartup = true),
        systems.parseSystemList(isStartup = false)
    )

    name.expectKind(nnkIdent)

    let allComponents = parsed.componentSet(name.strVal)

    let allQueries = newDirectiveSet[QueryDef](name.strVal, parsed.queries.toSeq)

    let allSpawns = newDirectiveSet[SpawnDef](name.strVal, parsed.spawns.toSeq)

    result = nnkStmtList.newTree(
        allComponents.createComponentEnum,
        allComponents.createComponentObj,
        allComponents.createQueryObj(allQueries),
        createWorldInstance(allComponents, allQueries),
        createQueryVars(allComponents, allQueries),
        createSpawnFunc(allComponents, allSpawns, allQueries),
    )

    echo result.repr


