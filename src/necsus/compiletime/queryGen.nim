import std/[tables, macros, options]
import
  tupleDirective, archetype, componentDef, tools, systemGen, archetypeBuilder, common,
  directiveArg
import ../runtime/[archetypeStore, query], ../util/[bits, blockstore]

iterator selectArchetypes(
    details: GenerateContext, query: TupleDirective
): Archetype[ComponentDef] =
  ## Iterates through the archetypes that contribute to a query
  for archetype in details.archetypes:
    if archetype.matches(query.filter):
      yield archetype

let state {.compileTime.} = ident("state")
let iter {.compileTime.} = ident("iter")
let eid {.compileTime.} = ident("eid")
let slot {.compileTime.} = ident("slot")

proc addLenPredicate(
    existing, row: NimNode,
    arch: Archetype[ComponentDef],
    arg: DirectiveArg,
    fn: NimNode,
): NimNode =
  if arg.component notin arch:
    return false.newLit

  let index = arch.indexOf(arg.component).newLit
  let newCheck = newCall(fn, nnkBracketExpr.newTree(row, index))
  return
    if existing.kind == nnkEmpty:
      newCheck
    else:
      infix(existing, "and", newCheck)

proc buildAddLen(query: TupleDirective, archetype: Archetype[ComponentDef]): NimNode =
  ## Builds the code for calculating the length of an archetype

  let archetypeIdent = archetype.ident

  # Builds a predicate that is able to determine whether a row should be counted against the length of a query.
  # This is needed because accessories are optional and not specifically tracked
  if query.hasAccessories:
    let row = genSym(nskParam, "row")

    var predicate = newEmptyNode()
    for arg in query.args:
      if arg.isAccessory:
        case arg.kind
        of Optional:
          discard
        of Include:
          predicate = predicate.addLenPredicate(row, archetype, arg, bindSym("isSome"))
        of Exclude:
          predicate = predicate.addLenPredicate(row, archetype, arg, bindSym("isNone"))

    if predicate.kind != nnkEmpty:
      let symbol = genSym(nskProc, "filter")
      let rowType = archetype.asStorageTuple
      return quote:
        proc `symbol`(`row`: var `rowType`): bool {.nimcall, gcsafe, raises: [].} =
          return `predicate`

        addLen(`appStateIdent`.`archetypeIdent`, result, `symbol`)

  # This is the simple case -- no accessories, so we can just trust the length of the archetype itself
  return quote:
    addLen(`appStateIdent`.`archetypeIdent`, result)

proc walkArchetypes(
    details: GenerateContext,
    name: string,
    query: TupleDirective,
    queryTupleType: NimNode,
): (NimNode, NimNode) {.used.} =
  ## Creates the views that bind an archetype to a query
  var lenCalculation = newStmtList()

  var iterCases: seq[NimNode]

  for archetype in details.selectArchetypes(query):
    lenCalculation.add(buildAddLen(query, archetype))

    let archetypeIdent = archetype.ident
    let convert = newConverter(archetype, query).name

    iterCases.add nnkOfBranch.newTree(
      iterCases.len.newLit,
      quote do:
        if likely(
          `convert`(`appStateIdent`.`archetypeIdent`.next(`iter`, `eid`), nil, `slot`)
        ):
          return true
      ,
    )

  let iteratorBody =
    if iterCases.len == 0:
      nnkReturnStmt.newTree(false.newLit)
    else:
      let maxLen = iterCases.len.newLit

      var iterCaseStmt = nnkCaseStmt.newTree()
      iterCaseStmt.add quote do:
        cast[range[0 .. `maxLen`]](`state`)
      iterCaseStmt.add(iterCases)
      iterCaseStmt.add nnkOfBranch.newTree(
        iterCases.len.newLit, nnkReturnStmt.newTree(false.newLit)
      )

      quote:
        while true:
          `iterCaseStmt`
          if `iter`.isDone:
            `state` += 1
            `iter` = default(BlockIter)

  return (lenCalculation, iteratorBody)

proc worldFields(name: string, dir: TupleDirective): seq[WorldField] =
  @[(name, nnkBracketExpr.newTree(bindSym("RawQuery"), dir.asTupleType))]

proc systemArg(queryType: NimNode, name: string): NimNode =
  let nameIdent = name.ident
  return quote:
    `appStateIdent`.`nameIdent`.`queryType`()

proc querySystemArg(name: string, dir: TupleDirective): NimNode =
  systemArg(bindSym("asQuery"), name)

proc fullQuerySystemArg(name: string, dir: TupleDirective): NimNode =
  systemArg(bindSym("asFullQuery"), name)

proc converters(ctx: GenerateContext, dir: TupleDirective): seq[ConverterDef] =
  for archetype in ctx.selectArchetypes(dir):
    result.add(newConverter(archetype, dir))

proc generate(
    details: GenerateContext, arg: SystemArg, name: string, dir: TupleDirective
): NimNode =
  ## Generates the code for instantiating queries
  if isFastCompileMode(fastQueryGen):
    return newEmptyNode()

  let queryTuple = dir.args.asTupleType
  let getLen = details.globalName(name & "_getLen")
  let getNext = details.globalName(name & "_getNext")

  case details.hook
  of GenerateHook.Outside:
    let appStateTypeName = details.appStateTypeName

    let (lenCalculation, iteratorBody) = details.walkArchetypes(name, dir, queryTuple)

    let trace = emitQueryTrace(
      "Query for ", $dir, " returned ", newCall(getLen, appStatePtr), " result(s)"
    )

    return quote:
      proc `getLen`(appStatePtr: pointer): uint {.nimcall.} =
        let `appStateIdent` {.used.} = cast[ptr `appStateTypeName`](appStatePtr)
        result = 0
        `lenCalculation`

      proc `getNext`(
          `appStatePtr`: pointer,
          `state`: var uint,
          `iter`: var BlockIter,
          `eid`: var EntityId,
          `slot`: var `queryTuple`,
      ): bool {.gcsafe, raises: [], nimcall.} =
        let `appStateIdent` {.used.} = cast[ptr `appStateTypeName`](`appStatePtr`)
        `trace`
        `iteratorBody`

  of GenerateHook.Standard:
    let ident = name.ident
    return quote:
      `appStateIdent`.`ident` =
        newQuery[`queryTuple`](`appStatePtr`, `getLen`, `getNext`)
  else:
    return newEmptyNode()

let queryGenerator* {.compileTime.} = newGenerator(
  ident = "Query",
  interest = {Standard, Outside},
  generate = generate,
  worldFields = worldFields,
  systemArg = querySystemArg,
  converters = converters,
)

let fullQueryGenerator* {.compileTime.} = newGenerator(
  ident = "FullQuery",
  interest = {Standard, Outside},
  generate = generate,
  worldFields = worldFields,
  systemArg = fullQuerySystemArg,
  converters = converters,
)
