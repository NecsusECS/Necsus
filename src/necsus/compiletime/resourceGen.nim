import macros, systemGen, monoDirective, common

proc requiresRef(node: NimNode): bool =
  ## Returns whether a node type needs to be wrapped in a ref
  case node.kind
  of nnkRefTy:
    return false
  of nnkBracketExpr:
    case node[0].typeKind
    of ntyTypeDesc:
      return requiresRef(node[1])
    of ntyRef:
      return false
    else:
      return true
  of nnkSym:
    let typ = node.getType
    return if typ.kind == nnkSym: true else: typ.requiresRef
  else:
    return true

proc worldFields(name: string, dir: MonoDirective): seq[WorldField] =
  let typ =
    if dir.argType.requiresRef:
      nnkRefTy.newTree(dir.argType)
    else:
      dir.argType
  return @[(name, typ)]

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
        if dir.argType.requiresRef:
          result.add quote do:
            new(`appStateIdent`.`varIdent`)
            `appStateIdent`.`varIdent`[] = `inputIdent`
        else:
          result.add quote do:
            `appStateIdent`.`varIdent` = `inputIdent`

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
  result = newDotExpr(appStateIdent, varIdent)
  if dir.argType.requiresRef:
    result = quote:
      `result`[]

let resourceGenerator* {.compileTime.} = newGenerator(
  ident = "Resource",
  interest = {Standard},
  generate = generateResource,
  worldFields = worldFields,
  systemArg = systemArg,
)
