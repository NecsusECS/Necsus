
import macros, sets
import archetype, archetypeBuilder, commonVars, systemGen

let lastTime {.compileTime.} = ident("lastTime")

proc deltaFields(name: string): seq[WorldField] = @[ (name, ident("float")), (lastTime.strVal, ident("float")) ]

proc generateDelta(details: GenerateContext): NimNode =
    let timeDelta = details.name.ident
    case details.hook
    of Late:
        return quote:
            `appStateIdent`.`timeDelta` = 0
    of BeforeLoop:
        return quote:
            `appStateIdent`.`lastTime` = `appStateIdent`.`startTime`
    of LoopStart:
        return quote:
            `appStateIdent`.`timeDelta` = `thisTime` - `appStateIdent`.`lastTime`
    of LoopEnd:
        return quote:
            `appStateIdent`.`lastTime` = `thisTime`
    else:
        return newEmptyNode()

let deltaGenerator* {.compileTime.} = newGenerator(
    ident = "TimeDelta", 
    generate = generateDelta, 
    worldFields = deltaFields,
)

proc elapsedFields(name: string): seq[WorldField] = @[ (name, ident("float")) ]

proc generateElapsed(details: GenerateContext): NimNode =
    let timeElapsed = details.name.ident
    case details.hook
    of Late:
        return quote:
            `appStateIdent`.`timeElapsed` = 0
    of LoopStart:
        return quote:
            `appStateIdent`.`timeElapsed` = `thisTime` - `startTime`
    else:
        return newEmptyNode()

let elapsedGenerator* {.compileTime.} = newGenerator(
    ident = "TimeElapsed",
    generate = generateElapsed,
    worldFields = elapsedFields,
)