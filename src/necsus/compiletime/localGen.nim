import macros, systemGen, monoDirective, common, std/strutils
import ../runtime/systemVar, ../util/nimNode

proc chooseLocalName(context, argName: NimNode, local: MonoDirective): string =
  var hash: string
  hash.addSignature(context)
  return context.symbols.join("_") & "_" & hash & "_" & argName.strVal

proc worldFields(name: string, dir: MonoDirective): seq[WorldField] =
  @[(name, nnkBracketExpr.newTree(bindSym("SystemVarData"), dir.argType))]

proc generateLocal(
    details: GenerateContext, arg: SystemArg, name: string, dir: MonoDirective
): NimNode =
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
  systemArg = systemArg,
)
