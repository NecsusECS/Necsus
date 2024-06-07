import macros, systemGen, monoDirective, common
import ../runtime/systemVar

proc chooseLocalName(context, argName: NimNode, local: MonoDirective): string = argName.signatureHash

proc worldFields(name: string, dir: MonoDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("SystemVarData"), dir.argType)) ]

proc generateLocal(details: GenerateContext, arg: SystemArg, name: string, dir: MonoDirective): NimNode =
    return newEmptyNode()

proc systemArg(name: string, dir: MonoDirective): NimNode =
    let nameIdent = name.ident
    return quote:
        Local(addr `appStateIdent`.`nameIdent`)

let localGenerator* {.compileTime.} = newGenerator(
    ident = "Local",
    interest = {},
    generate = generateLocal,
    chooseName = chooseLocalName,
    worldFields = worldFields,
    systemArg = systemArg
)