import macros, directiveSet, systemGen, monoDirective, options, common
import ../runtime/systemVar

proc worldFields(name: string, dir: MonoDirective): seq[WorldField] =
     @[ (name, nnkBracketExpr.newTree(bindSym("SystemVarData"), dir.argType)) ]

proc generateShared(details: GenerateContext, arg: SystemArg, name: string, dir: MonoDirective): NimNode =

    if isFastCompileMode(fastSharedGen):
        return newEmptyNode()

    result = newStmtList()
    case details.hook
    of Standard:
        let varIdent = ident(name)

        # Fill in any values from arguments passed to the app
        for (inputName, inputDir) in details.inputs:
            if dir == inputDir:
                let inputIdent = inputName.ident
                result.add quote do:
                    systemVar.set(Shared(addr `appStateIdent`.`varIdent`), `inputIdent`)
    else:
        discard

proc systemReturn(args: DirectiveSet[SystemArg], returns: MonoDirective): Option[NimNode] =
    for name, directive in args:
        if directive.monoDir == returns:
            let stateIdent = name.ident
            let returnCode = quote:
                getOrRaise(Shared(addr `appStateIdent`.`stateIdent`))
            return some(returnCode)
    return none(NimNode)

proc systemArg(name: string, dir: MonoDirective): NimNode =
    let nameIdent = name.ident
    return quote:
        Shared(addr `appStateIdent`.`nameIdent`)

let sharedGenerator* {.compileTime.} = newGenerator(
    ident = "Shared",
    interest = { Standard },
    generate = generateShared,
    systemReturn = systemReturn,
    worldFields = worldFields,
    systemArg = systemArg
)
