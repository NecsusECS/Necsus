import macros
import common, systemGen, ../runtime/directives

let tickId {.compileTime.} = ident("tickId")
let getTickId {.compileTime.} = ident("getTickId")

proc fields(name: string): seq[WorldField] =
    @[ (tickId.strVal, ident("uint32")), (getTickId.strVal, bindSym("TickId")) ]

proc sysArg(name: string): NimNode =
    return quote:
        `appStateIdent`.`getTickId`

proc generate(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    let tickGenProc = details.globalName(name)
    case details.hook
    of Outside:
        let appType = details.appStateTypeName
        return quote:
            proc `tickGenProc`(`appStateIdent`: pointer): uint32 {.gcsafe, raises: [], fastcall.} =
                let `appStatePtr` = cast[ptr `appType`](`appStateIdent`)
                return `appStatePtr`.`tickId`
    of Standard:
        return quote:
            `appStateIdent`.`getTickId` = newCallbackDir(`appStatePtr`, `tickGenProc`)
    of LoopStart:
        return quote:
            `appStateIdent`.`tickId` += 1
    else:
        return newEmptyNode()

let tickIdGenerator* {.compileTime.} = newGenerator(
    ident = "TickId",
    interest = { LoopStart, Standard, Outside },
    generate = generate,
    worldFields = fields,
    systemArg = sysArg,
)
