import macros, strutils
import common, systemGen, ../runtime/directives
import ../util/nimNode

proc fields(name: string): seq[WorldField] =
  @[(name, bindSym("DynamicSystem")), (name & "_setter", bindSym("RegisterSystem"))]

proc sysArg(name: string): NimNode =
  newDotExpr(appStateIdent, (name & "_setter").ident)

proc generate(details: GenerateContext, arg: SystemArg, name: string): NimNode =
  if isFastCompileMode(fastRegisterSystem):
    return newEmptyNode()

  let nameIdent = name.ident
  let setterIdent = (name & "_setter").ident
  case details.hook
  of Standard:
    return quote:
      `appStateIdent`.`nameIdent` = proc(): void =
        discard
      `appStateIdent`.`setterIdent` = proc(system: DynamicSystem) {.closure.} =
        `appStatePtr`.`nameIdent` = system
  of LoopInPlace:
    return quote:
      `appStateIdent`.`nameIdent`()
  else:
    return newEmptyNode()

proc chooseRegisterSystemName(context, name: NimNode): string =
  var hash: string
  hash.addSignature(context)
  context.symbols.join("_") & "_" & hash & "_" & name.extractStr

let registerSystemGenerator* {.compileTime.} = newGenerator(
  ident = "RegisterSystem",
  interest = {Standard, LoopInPlace},
  generate = generate,
  worldFields = fields,
  systemArg = sysArg,
  chooseName = chooseRegisterSystemName,
)
