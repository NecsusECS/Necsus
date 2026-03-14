import macros, strutils
import common, systemGen, monoDirective
import ../runtime/directives
import ../util/nimNode

proc fields(name: string, dir: MonoDirective): seq[WorldField] =
  let eventType = dir.argType
  let handlerType = nnkBracketExpr.newTree(bindSym("DynamicEventSystem"), eventType)
  let setterType = nnkBracketExpr.newTree(bindSym("RegisterEventSystem"), eventType)
  @[(name, handlerType), (name & "_setter", setterType)]

proc sysArg(name: string, dir: MonoDirective): NimNode =
  newDotExpr(appStateIdent, (name & "_setter").ident)

proc generate(
    details: GenerateContext, arg: SystemArg, name: string, dir: MonoDirective
): NimNode =
  if isFastCompileMode(fastRegisterSystem):
    return newEmptyNode()

  let nameIdent = name.ident
  let setterIdent = (name & "_setter").ident
  let eventType = dir.argType
  case details.hook
  of Standard:
    return quote:
      `appStateIdent`.`nameIdent` = proc(event: `eventType`): void =
        discard
      `appStateIdent`.`setterIdent` =
        proc(system: DynamicEventSystem[`eventType`]) {.closure.} =
          `appStatePtr`.`nameIdent` = system
  else:
    return newEmptyNode()

proc chooseRegisterEventSystemName(context, argName: NimNode, dir: MonoDirective): string =
  var hash: string
  hash.addSignature(context)
  context.symbols.join("_") & "_" & hash & "_" & argName.strVal

let registerEventSystemGenerator* {.compileTime.} = newGenerator(
  ident = "RegisterEventSystem",
  interest = {Standard},
  generate = generate,
  worldFields = fields,
  systemArg = sysArg,
  chooseName = chooseRegisterEventSystemName,
)
