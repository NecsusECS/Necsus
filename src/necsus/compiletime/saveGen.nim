import macros, systemGen, common, ../runtime/directives

proc worldFields(name: string): seq[WorldField] = @[ (name, bindSym("Save")) ]

proc generate(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    let saveWrapperName = details.globalName(name)

    case details.hook
    of Outside:
        let appType = details.appStateTypeName
        return quote:
            proc`saveWrapperName`(
                `appStatePtr`: pointer
            ): string {.raises: [IOError, OSError, ValueError, Exception], fastcall, used.} =
                save(cast[ptr `appType`](`appStatePtr`))
    of Late:
        let nameIdent = name.ident
        return quote:
            `appStateIdent`.`nameIdent` = newCallbackDir(`appStatePtr`, `saveWrapperName`)
    else:
        return newEmptyNode()

let saveGenerator* {.compileTime.} = newGenerator(
    ident = "Save",
    interest = { Late, Outside },
    generate = generate,
    worldFields = worldFields,
)
