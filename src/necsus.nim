import necsus / [entity, query, world, parse, codegen]
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

    result = nnkStmtList.newTree(
        createComponentEnum(name.strVal, parsed.componentDefs))

    echo result.repr


