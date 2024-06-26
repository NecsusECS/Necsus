import macros, systemGen, common, ../runtime/directives

proc worldFields(name: string): seq[WorldField] = @[ (name, bindSym("Restore")) ]

let json {.compileTime.} = "json".ident

proc generate(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    case details.hook
    of Late:
        let nameIdent = name.ident
        return quote:
            `appStateIdent`.`nameIdent` = proc(`json`: string): auto = restore(`appStateIdent`, `json`)
    else:
        return newEmptyNode()

let restoreGenerator* {.compileTime.} = newGenerator(
    ident = "Restore",
    interest = { Late },
    generate = generate,
    worldFields = worldFields,
)

