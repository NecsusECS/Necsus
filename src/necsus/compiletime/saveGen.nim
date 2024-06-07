import macros, systemGen, common, ../runtime/directives

proc worldFields(name: string): seq[WorldField] = @[ (name, bindSym("Save")) ]

proc generate(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    case details.hook
    of Late:
        let nameIdent = name.ident
        return quote:
            `appStateIdent`.`nameIdent` = proc(): string = save(`appStateIdent`)
    else:
        return newEmptyNode()

let saveGenerator* {.compileTime.} = newGenerator(
    ident = "Save",
    interest = { Late },
    generate = generate,
    worldFields = worldFields,
)
