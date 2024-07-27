
import macros, sets
import archetype, archetypeBuilder, common, systemGen, ../runtime/directives

let lastTime {.compileTime.} = ident("lastTime")

proc deltaFields(name: string): seq[WorldField] =
    @[ (name, bindSym("TimeDelta")), (lastTime.strVal, bindSym("BiggestFloat")) ]

proc generateDelta(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    let timeDelta = name.ident
    let timeDeltaProc = details.globalName(name)
    case details.hook
    of Outside:
        let appType = details.appStateTypeName
        return quote:
            proc `timeDeltaProc`(`appStateIdent`: pointer): BiggestFloat {.gcsafe, raises: [], fastcall.} =
                let `appStatePtr` = cast[ptr `appType`](`appStateIdent`)
                return `appStatePtr`.`thisTime` - `appStatePtr`.`lastTime`
    of Late:
        return quote:
            `appStateIdent`.`timeDelta` = newCallbackDir(`appStatePtr`, `timeDeltaProc`)
    of BeforeLoop:
        return quote:
            `appStateIdent`.`lastTime` = `appStateIdent`.`startTime`
    of LoopEnd:
        return quote:
            `appStateIdent`.`lastTime` = `appStateIdent`.`thisTime`
    else:
        return newEmptyNode()

let deltaGenerator* {.compileTime.} = newGenerator(
    ident = "TimeDelta",
    interest = { Late, BeforeLoop, LoopEnd, Outside },
    generate = generateDelta,
    worldFields = deltaFields,
)

proc elapsedFields(name: string): seq[WorldField] = @[ (name, bindSym("TimeElapsed")) ]

proc generateElapsed(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    let timeElapsed = name.ident
    let timeElapsedProc = details.globalName(name)
    case details.hook
    of Outside:
        let appType = details.appStateTypeName
        return quote:
            proc `timeElapsedProc`(`appStateIdent`: pointer): BiggestFloat {.gcsafe, raises: [], fastcall.} =
                let `appStatePtr` = cast[ptr `appType`](`appStateIdent`)
                return `appStatePtr`.`thisTime` - `appStatePtr`.`startTime`
    of Late:
        return quote:
            `appStateIdent`.`thisTime` = `appStateIdent`.`startTime`
            `appStateIdent`.`timeElapsed` = newCallbackDir(`appStatePtr`, `timeElapsedProc`)
    else:
        return newEmptyNode()

let elapsedGenerator* {.compileTime.} = newGenerator(
    ident = "TimeElapsed",
    interest = { Late, Outside },
    generate = generateElapsed,
    worldFields = elapsedFields,
)
