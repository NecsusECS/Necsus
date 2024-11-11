import macros, systemGen, monoDirective, common
import ../runtime/systemVar

proc chooseLocalName(context, argName: NimNode, local: MonoDirective): string =
    case argName.kind
    of nnkSym:
        return argName.signatureHash
    of nnkIdent:
        context.expectKind({ nnkSym })
        return context.strVal & "_" & context.signatureHash & "_" & argName.strVal
    else:
        argName.expectKind({ nnkSym, nnkIdent })

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