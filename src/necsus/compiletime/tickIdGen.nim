import macros
import commonVars, systemGen, ../runtime/directives

let tickId {.compileTime.} = ident("tickId")

proc fields(name: string): seq[WorldField] = @[ (tickId.strVal, ident("uint")) ]

proc sysArg(name: string): NimNode =
    return quote:
        TickId(addr `appStateIdent`.`tickId`)

proc generate(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    case details.hook
    of LoopStart:
        return quote:
            `appStateIdent`.`tickId` += 1
    else:
        return newEmptyNode()

let tickIdGenerator* {.compileTime.} = newGenerator(
    ident = "TickId",
    interest = { LoopStart },
    generate = generate,
    worldFields = fields,
    systemArg = sysArg,
)
