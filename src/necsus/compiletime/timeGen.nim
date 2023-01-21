
import macros, sets
import archetype, archetypeBuilder, commonVars, systemGen

let lastTime {.compileTime.} = ident("lastTime")

proc generateDelta(details: GenerateContext): NimNode =
    let timeDelta = details.name.ident
    case details.hook
    of Late:
        return quote:
            var `timeDelta`: float = 0
    of BeforeLoop:
        return quote:
            var `lastTime`: float = `startTime`
    of LoopStart:
        return quote:
            `timeDelta` = `thisTime` - `lastTime`
    of LoopEnd:
        return quote:
            `lastTime` = `thisTime`
    else:
        return newEmptyNode()

let deltaGenerator* {.compileTime.} = newGenerator("TimeDelta", generateDelta)

proc generateElapsed(details: GenerateContext): NimNode =
    let timeElapsed = details.name.ident
    case details.hook
    of Late:
        return quote:
            var `timeElapsed`: float = 0
    of LoopStart:
        return quote:
            `timeElapsed` = `thisTime` - `startTime`
    else:
        return newEmptyNode()

let elapsedGenerator* {.compileTime.} = newGenerator("TimeElapsed", generateElapsed)