import macros, systemGen, commonVars, ../runtime/directives, std/streams

proc worldFields(name: string): seq[WorldField] = @[ (name, bindSym("Save")) ]

proc generate(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    case details.hook
    of Late:
        let nameIdent = name.ident
        let intoIdent = "into".ident
        return quote:
            `appStateIdent`.`nameIdent` = proc(`intoIdent`: var Stream): auto = save(`appStateIdent`, `intoIdent`)
    else:
        return newEmptyNode()

let saveGenerator* {.compileTime.} = newGenerator(
    ident = "Save",
    interest = { Late },
    generate = generate,
    worldFields = worldFields,
)
