import macros, systemGen, monoDirective, commonVars
import ../runtime/systemVar

proc chooseLocalName(uniqId: string, local: MonoDirective): string = uniqId

proc worldFields(name: string, dir: MonoDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("Local"), dir.argType)) ]

proc generateLocal(details: GenerateContext, dir: MonoDirective): NimNode =
    case details.hook
    of Standard:
        let varIdent = ident(details.name)
        let argType = dir.argType
        return quote:
            `appStateIdent`.`varIdent` = newLocal[`argType`]()
    else:
        return newEmptyNode()

let localGenerator* {.compileTime.} = newGenerator(
    ident = "Local",
    generate = generateLocal,
    chooseName = chooseLocalName,
    worldFields = worldFields
)