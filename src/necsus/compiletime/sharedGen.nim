import macros, directiveSet, systemGen, monoDirective, options
import ../runtime/systemVar

proc parseShared(argName: string, component: NimNode): MonoDirective = newSharedDef(component)

proc generateShared(details: GenerateContext, dir: MonoDirective): NimNode =
    result = newStmtList()
    case details.hook
    of Standard:
        let varIdent = ident(details.name)
        let argType = dir.argType
        result.add quote do:
            var `varIdent` = newShared[`argType`]()

        # Fill in any values from arguments passed to the app
        for (inputName, inputDir) in details.inputs:
            if dir == inputDir:
                let inputIdent = inputName.ident
                result.add quote do:
                    systemVar.set(`varIdent`, `inputIdent`)
    else:
        discard

proc systemReturn(args: DirectiveSet[SystemArg], returns: MonoDirective): Option[NimNode] =
    for name, directive in args:
        if directive.monoDir == returns:
            return some(newCall(bindSym("get"), ident(name)))
    return none(NimNode)

let sharedGenerator* {.compileTime.} = newGenerator(
    ident = "Shared",
    parse = parseShared,
    generate = generateShared,
    systemReturn = systemReturn
)
