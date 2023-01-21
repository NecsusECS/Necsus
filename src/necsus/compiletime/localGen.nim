import macros, systemGen, monoDirective
import ../runtime/systemVar

proc parseLocal(argName: string, component: NimNode): MonoDirective = newLocalDef(component)

proc chooseLocalName(uniqId: string, local: MonoDirective): string = uniqId

proc generateLocal(details: GenerateContext, dir: MonoDirective): NimNode =
    case details.hook
    of Standard:
        let varIdent = ident(details.name)
        let argType = dir.argType
        return quote:
            var `varIdent` = newLocal[`argType`]()
    else:
        return newEmptyNode()

let localGenerator* {.compileTime.} = newGenerator(
    ident = "Local",
    parse = parseLocal,
    generate = generateLocal,
    chooseName = chooseLocalName
)