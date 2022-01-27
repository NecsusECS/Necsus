import macros, times, codeGenInfo, parse, directiveSet, directive, sequtils, queryGen, componentSet, localDef

let timeDelta {.compileTime.} = ident("timeDelta")

proc callSystems(codeGenInfo: CodeGenInfo, systems: openarray[ParsedSystem]): NimNode =
    result = newStmtList()
    for system in systems:
        let props = system.args.toSeq.map do (arg: SystemArg) -> NimNode:
            case arg.kind
            of SystemArgKind.Spawn:
                ident(codeGenInfo.spawns.nameOf(arg.spawn))
            of SystemArgKind.Query:
                ident(codeGenInfo.queries.nameOf(arg.query))
            of SystemArgKind.Attach:
                ident(codeGenInfo.attaches.nameOf(arg.attach))
            of SystemArgKind.Detach:
                ident(codeGenInfo.detaches.nameOf(arg.detach))
            of SystemArgKind.TimeDelta:
                timeDelta
            of SystemArgKind.Delete:
                deleteProc
            of SystemArgKind.Local:
                ident(codeGenInfo.locals.nameOf(arg.local))

        result.add(newCall(ident(system.symbol), props))

proc createDelteFinalizers(codeGenInfo: CodeGenInfo): NimNode =
    ## Creates method calls to process deleted entities
    result = newStmtList()

    # Delete entities out of queries
    for (name, _) in codeGenInfo.queries:
        let queryStorage = name.queryStorageIdent
        result.add quote do:
            finalizeDeletes(`queryStorage`)

    # Delete entities out of components
    for component in codeGenInfo.components:
        result.add quote do:
            deleteComponents(`worldIdent`, `componentsIdent`.`component`)

proc createTickRunner*(codeGenInfo: CodeGenInfo, runner: NimNode): NimNode =
    ## Creates the code required to execute a single tick within the world

    let startups = codeGenInfo.callSystems(codeGenInfo.systems.filterIt(it.isStartup))
    let execSystems = codeGenInfo.callSystems(codeGenInfo.systems.filterIt(not it.isStartup))
    let deleteFinalizers = codeGenInfo.createDelteFinalizers()
    let lastTime = ident("lastTime")
    let thisTime = ident("thisTime")

    result = quote do:
        var `lastTime`: float = epochTime()
        var `timeDelta`: float = 0
        `startups`
        `runner` do:
            let `thisTime` = epochTime()
            `timeDelta` = `thisTime` - `lastTime`
            block:
                `execSystems`
            `lastTime` = `thisTime`
            `deleteFinalizers`
            world.clearDeletedEntities()
