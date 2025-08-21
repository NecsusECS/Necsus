import macros, systemGen, monoDirective, common

proc worldFields(name: string, dir: MonoDirective): seq[WorldField] =
  @[(name, nnkRefTy.newTree(dir.argType))]

proc generateResource(
    details: GenerateContext, arg: SystemArg, name: string, dir: MonoDirective
): NimNode =
  if isFastCompileMode(fastResourceGen):
    return newEmptyNode()

  result = newStmtList()
  case details.hook
  of Standard:
    let varIdent = ident(name)

    # Fill in any values from arguments passed to the app
    var filled = false
    for (inputName, inputDir) in details.inputs:
      if dir == inputDir:
        filled = true
        let inputIdent = inputName.ident
        result.add quote do:
          new(`appStateIdent`.`varIdent`)
          `appStateIdent`.`varIdent`[] = `inputIdent`

    if not filled:
      warning("Resource of type " & dir.argType.repr & " used here", dir.argType)
      error(
        "Resource of type " & dir.argType.repr & " must be passed in as an app argument",
        details.appProc,
      )
  else:
    discard

proc systemArg(name: string, dir: MonoDirective): NimNode =
  let varIdent = ident(name)
  return quote:
    `appStateIdent`.`varIdent`[]

let resourceGenerator* {.compileTime.} = newGenerator(
  ident = "Resource",
  interest = {Standard},
  generate = generateResource,
  worldFields = worldFields,
  systemArg = systemArg,
)
