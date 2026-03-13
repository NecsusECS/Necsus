import macros
import common, systemGen, monoDirective

proc fields(name: string, dir: MonoDirective): seq[WorldField] =
  let eventType = dir.argType
  let procType = nnkProcTy.newTree(
    nnkFormalParams.newTree(
      newEmptyNode(),
      nnkIdentDefs.newTree(ident("event"), eventType, newEmptyNode()),
    ),
    nnkPragma.newTree(ident("closure")),
  )
  @[(name, procType)]

proc sysArg(name: string, dir: MonoDirective): NimNode =
  let nameIdent = name.ident
  let eventType = dir.argType
  return quote:
    proc(system: proc(event: `eventType`): void {.closure.}) {.closure.} =
      `appStatePtr`.`nameIdent` = system

proc generate(
    details: GenerateContext, arg: SystemArg, name: string, dir: MonoDirective
): NimNode =
  if isFastCompileMode(fastRegisterSystem):
    return newEmptyNode()

  let nameIdent = name.ident
  let eventType = dir.argType
  case details.hook
  of Standard:
    return quote:
      `appStateIdent`.`nameIdent` = proc(event: `eventType`): void =
        discard
  else:
    return newEmptyNode()

let registerEventSystemGenerator* {.compileTime.} = newGenerator(
  ident = "RegisterEventSystem",
  interest = {Standard},
  generate = generate,
  worldFields = fields,
  systemArg = sysArg,
  chooseName = proc(context, argName: NimNode, dir: MonoDirective): string =
    argName.strVal,
)
