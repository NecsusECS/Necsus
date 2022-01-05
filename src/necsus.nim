import necsus / [entity, query, world, parse]
export entity, query, world

import sequtils

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

    echo parsed

