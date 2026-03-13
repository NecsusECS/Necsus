import macros
import common, systemGen, ../runtime/directives

proc fields(name: string): seq[WorldField] =
  @[(name, bindSym("DynamicSystem"))]

proc sysArg(name: string): NimNode =
  let nameIdent = name.ident
  return quote:
    proc(system: DynamicSystem) {.closure.} =
      `appStatePtr`.`nameIdent` = system

proc generate(details: GenerateContext, arg: SystemArg, name: string): NimNode =
  if isFastCompileMode(fastRegisterSystem):
    return newEmptyNode()

  let nameIdent = name.ident
  case details.hook
  of Standard:
    return quote:
      `appStateIdent`.`nameIdent` = proc(): void =
        discard
  of LoopInPlace:
    return quote:
      `appStateIdent`.`nameIdent`()
  else:
    return newEmptyNode()

let registerSystemGenerator* {.compileTime.} = newGenerator(
  ident = "RegisterSystem",
  interest = {Standard, LoopInPlace},
  generate = generate,
  worldFields = fields,
  systemArg = sysArg,
  chooseName = proc(context, name: NimNode): string =
    name.strVal,
)
