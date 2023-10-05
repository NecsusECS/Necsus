import macros, systemGen, monoDirective, commonVars
import ../runtime/systemVar

proc chooseLocalName(uniqId: string, local: MonoDirective): string = uniqId

proc worldFields(name: string, dir: MonoDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("SystemVarData"), dir.argType)) ]

proc generateLocal(details: GenerateContext, arg: SystemArg, name: string, dir: MonoDirective): NimNode =
    case details.hook
    of Standard:
        let varIdent = ident(name)
        let argType = dir.argType
        return quote:
            `appStateIdent`.`varIdent` = newSystemVar[`argType`]()
    else:
        return newEmptyNode()

proc systemArg(name: string, dir: MonoDirective): NimNode =
    let nameIdent = name.ident
    return quote:
        Local(addr `appStateIdent`.`nameIdent`)

let localGenerator* {.compileTime.} = newGenerator(
    ident = "Local",
    generate = generateLocal,
    chooseName = chooseLocalName,
    worldFields = worldFields,
    systemArg = systemArg
)