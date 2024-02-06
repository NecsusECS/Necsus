
import macros, sets
import archetype, archetypeBuilder, commonVars, systemGen, ../runtime/directives

let lastTime {.compileTime.} = ident("lastTime")

proc deltaFields(name: string): seq[WorldField] =
    @[ (name, bindSym("TimeDelta")), (lastTime.strVal, bindSym("Nfloat")) ]

proc generateDelta(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    let timeDelta = name.ident
    case details.hook
    of Late:
        return quote:
            `appStateIdent`.`timeDelta` = proc(): auto = `appStateIdent`.`thisTime` - `appStateIdent`.`lastTime`
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
    interest = { Late, BeforeLoop, LoopEnd },
    generate = generateDelta,
    worldFields = deltaFields,
)

proc elapsedFields(name: string): seq[WorldField] = @[ (name, bindSym("TimeElapsed")) ]

proc generateElapsed(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    let timeElapsed = name.ident
    case details.hook
    of Late:
        return quote:
            `appStateIdent`.`thisTime` = `appStateIdent`.`startTime`
            `appStateIdent`.`timeElapsed` = proc(): auto = `appStateIdent`.`thisTime` - `appStateIdent`.`startTime`
    else:
        return newEmptyNode()

let elapsedGenerator* {.compileTime.} = newGenerator(
    ident = "TimeElapsed",
    interest = { Late },
    generate = generateElapsed,
    worldFields = elapsedFields,
)
