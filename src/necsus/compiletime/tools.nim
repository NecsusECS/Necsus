import macros, options, sequtils
import tupleDirective, componentDef, archetype, systemGen, directiveArg, common
import ../runtime/query

proc asTupleType*(components: openarray[ComponentDef]): NimNode =
  ## Creates a tuple type from a list of components
  result = nnkTupleConstr.newTree()
  for comp in components:
    result.add(comp.node)

proc asTupleType*(args: openarray[DirectiveArg]): NimNode =
  ## Creates a tuple type from a list of components
  result = nnkTupleConstr.newTree()
  for arg in args:
    let componentIdent =
      if arg.isPointer:
        nnkPtrTy.newTree(arg.component.ident)
      else:
        arg.component.ident
    case arg.kind
    of Include:
      result.add(componentIdent)
    of Exclude:
      result.add(nnkBracketExpr.newTree(bindSym("Not"), componentIdent))
    of Optional:
      result.add(nnkBracketExpr.newTree(bindSym("Option"), componentIdent))

proc asTupleType*(tupleDir: TupleDirective): NimNode =
  tupleDir.args.toSeq.asTupleType

proc componentIds*(dir: TupleDirective): NimNode =
  ## The column ids a directive wants, one per argument and in argument order.
  ##
  ## Component ids are global, so this is the same list no matter which archetype it gets
  ## applied to -- including for an excluded argument, which names a component the
  ## archetype is guaranteed not to have and so resolves to no column at all
  result = nnkBracket.newTree()
  for arg in dir.args:
    result.add(arg.component.columnId)

proc accessoryArgs*(dir: TupleDirective): NimNode =
  ## The presence column standing behind each argument of a directive, one per argument
  ## and in argument order, or no column at all for an argument that is not an accessory.
  ##
  ## Being an accessory is a property of a component rather than of an archetype, so this
  ## is the same list wherever it gets applied. Whether the archetype in hand actually
  ## carries the accessory is a separate question, and one the column lookup answers
  result = nnkBracket.newTree()
  for arg in dir.args:
    result.add(
      if arg.isAccessory:
        arg.component.presenceColumnId
      else:
        bindSym("NO_ACCESSORY")
    )

iterator archetypeCases*(
    details: GenerateContext
): tuple[ofBranch: NimNode, archetype: Archetype[ComponentDef]] =
  for archetype in details.archetypes:
    yield (archetype.idSymbol, archetype)

iterator both*(a, b: auto): auto =
  ## Yields values from one iterator then another
  for item in a:
    yield item
  for item in b:
    yield item

proc joinStrs*(args: varargs[NimNode]): NimNode =
  ## Joins a set of stringable nim nodes into a string
  if args.len == 0:
    result = newLit("")
  else:
    result = newEmptyNode()
    for arg in args:
      let argStr = nnkPrefix.newTree(ident("$"), arg)
      if result.kind == nnkEmpty:
        result = argStr
      else:
        result = nnkInfix.newTree(ident("&"), result, argStr)

proc loggable*(node: NimNode): NimNode =
  node

proc loggable*(str: string): NimNode =
  newLit(str)

proc emitLog*(args: varargs[NimNode, loggable]): NimNode =
  ## Generates code to emit a log message
  let msg = args.joinStrs
  return quote:
    `appStateIdent`.config.log(`msg`)

proc emitEntityTrace*(args: varargs[NimNode, loggable]): NimNode =
  ## Emits function call for logging an entity related event
  return
    if defined(necsusEntityTrace):
      emitLog(args)
    else:
      return newEmptyNode()

proc emitEventTrace*(args: varargs[NimNode, loggable]): NimNode =
  ## Emits code needed to generate an event tracing log
  return
    if defined(necsusEventTrace):
      emitLog(args)
    else:
      return newEmptyNode()

proc emitQueryTrace*(args: varargs[NimNode, loggable]): NimNode =
  ## Emits code needed to generate query tracing logs
  return
    if defined(necsusQueryTrace):
      emitLog(args)
    else:
      return newEmptyNode()

proc emitSaveTrace*(args: varargs[NimNode, loggable]): NimNode =
  ## Emits code needed to generate save tracing logs
  return
    if defined(necsusSaveTrace):
      emitLog(args)
    else:
      return newEmptyNode()
