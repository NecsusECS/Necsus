import macros, directiveSet, systemGen, monoDirective, options, commonVars
import ../runtime/systemVar

proc worldFields(name: string, dir: MonoDirective): seq[WorldField] =
     @[ (name, nnkBracketExpr.newTree(bindSym("Shared"), dir.argType)) ]

proc generateShared(details: GenerateContext, dir: MonoDirective): NimNode =
    result = newStmtList()
    case details.hook
    of Standard:
        let varIdent = ident(details.name)
        let argType = dir.argType
        result.add quote do:
            `appStateIdent`.`varIdent` = newShared[`argType`]()

        # Fill in any values from arguments passed to the app
        for (inputName, inputDir) in details.inputs:
            if dir == inputDir:
                let inputIdent = inputName.ident
                result.add quote do:
                    systemVar.set(`appStateIdent`.`varIdent`, `inputIdent`)
    else:
        discard

proc systemReturn(args: DirectiveSet[SystemArg], returns: MonoDirective): Option[NimNode] =
    for name, directive in args:
        if directive.monoDir == returns:
            let stateIdent = name.ident
            let returnCode = quote:
                get(`appStateIdent`.`stateIdent`)
            return some(returnCode)
    return none(NimNode)

let sharedGenerator* {.compileTime.} = newGenerator(
    ident = "Shared",
    generate = generateShared,
    systemReturn = systemReturn,
    worldFields = worldFields,
)
