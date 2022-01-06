import necsus / [entity, query, world, parse, codegen, componentSet]
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

    result = nnkStmtList.newTree(
        allComponents.createComponentEnum,
        allComponents.createComponentObj)

    echo result.repr


