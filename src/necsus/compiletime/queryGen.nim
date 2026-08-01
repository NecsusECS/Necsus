import std/[tables, macros, options]
import
  tupleDirective, archetype, componentDef, tools, systemGen, archetypeBuilder, common,
  directiveArg
import ../runtime/[archetypeStore, query], ../util/bits

iterator selectArchetypes(
    details: GenerateContext, query: TupleDirective
): Archetype[ComponentDef] =
  ## Iterates through the archetypes that contribute to a query
  for archetype in details.archetypes:
    if archetype.matches(query.filter):
      yield archetype

let state {.compileTime.} = ident("state")
let cols {.compileTime.} = ident("cols")

proc buildLen(query: TupleDirective, archetype: Archetype[ComponentDef]): NimNode =
  ## Adds the number of rows in one archetype that a query matches onto a running total.
  ##
  ## Usually that is every row it holds, because an archetype either matches a query or it
  ## does not. An accessory is what breaks that: it belongs to an entity rather than to an
  ## archetype, so an archetype can hold rows both with and without one, and a query that
  ## required or excluded it has to look at the rows to know how many it has
  let archetypeIdent = archetype.ident
  let index = genSym(nskForVar, "index")

  var condition = newEmptyNode()
  for arg in query.args:
    if not arg.isAccessory or arg.component notin archetype:
      continue

    let check =
      case arg.kind
      of Include:
        bindSym("isSome")
      of Exclude:
        bindSym("isNone")
      of Optional:
        continue

    let readColumn =
      nnkBracketExpr.newTree(bindSym("getColumn"), arg.component.columnType)
    let columnId = arg.component.columnId
    let present = quote:
      `check`(`readColumn`(`appStateIdent`.`archetypeIdent`, `columnId`)[`index`])

    condition =
      if condition.kind == nnkEmpty:
        present
      else:
        nnkInfix.newTree(ident("and"), condition, present)

  if condition.kind == nnkEmpty:
    return quote:
      addLen(`appStateIdent`.`archetypeIdent`, result)

  let rows = bindSym("rows")
  return quote:
    for `index` in 0'u32 ..< `rows`(`appStateIdent`.`archetypeIdent`):
      if `condition`:
        result += 1

proc walkArchetypes(
    details: GenerateContext,
    name: string,
    query: TupleDirective,
    queryTupleType: NimNode,
): (NimNode, NimNode) {.used.} =
  ## Creates the views that bind an archetype to a query
  var lenCalculation = newStmtList()

  var iterCases: seq[NimNode]

  let ids = query.componentIds
  let accessories = query.accessoryArgs

  for archetype in details.selectArchetypes(query):
    let archetypeIdent = archetype.ident

    lenCalculation.add query.buildLen(archetype)

    # These are bound here rather than left to be resolved where this code is pasted, so
    # that a name in the app being generated can not shadow them
    let rows = bindSym("rows")
    let newQueryCols = bindSym("newQueryCols")

    # An archetype hands over every column the query asked for in one go, so the state
    # moves on as soon as the archetype has been asked, whether or not it had rows to give
    iterCases.add nnkOfBranch.newTree(
      iterCases.len.newLit,
      quote do:
        `state` += 1
        if `rows`(`appStateIdent`.`archetypeIdent`) > 0'u32:
          `cols` = `newQueryCols`[`queryTupleType`](
            `appStateIdent`.`archetypeIdent`, `ids`, `accessories`
          )
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

proc generate(
    details: GenerateContext, arg: SystemArg, name: string, dir: TupleDirective
): NimNode =
  ## Generates the code for instantiating queries
  if isFastCompileMode(fastQueryGen):
    return newEmptyNode()

  let queryTuple = dir.args.asTupleType
  let getLen = details.globalName(name & "_getLen")
  let getCols = details.globalName(name & "_getCols")

  case details.hook
  of GenerateHook.Outside:
    let appStateTypeName = details.appStateTypeName

    let (lenCalculation, iteratorBody) = details.walkArchetypes(name, dir, queryTuple)

    let trace = emitQueryTrace(
      "Query for ", $dir, " returned ", newCall(getLen, appStatePtr), " result(s)"
    )

    return quote:
      proc `getLen`(appStatePtr: pointer): Natural {.nimcall.} =
        let `appStateIdent` {.used.} = cast[ptr `appStateTypeName`](appStatePtr)
        result = 0
        `lenCalculation`

      proc `getCols`(
          `appStatePtr`: pointer, `state`: var uint, `cols`: var QueryCols[`queryTuple`]
      ): bool {.gcsafe, raises: [], nimcall.} =
        let `appStateIdent` {.used.} = cast[ptr `appStateTypeName`](`appStatePtr`)
        `trace`
        `iteratorBody`

  of GenerateHook.Standard:
    let ident = name.ident
    return quote:
      `appStateIdent`.`ident` =
        newQuery[`queryTuple`](`appStatePtr`, `getLen`, `getCols`)
  else:
    return newEmptyNode()

let queryGenerator* {.compileTime.} = newGenerator(
  ident = "Query",
  interest = {Standard, Outside},
  generate = generate,
  worldFields = worldFields,
  systemArg = querySystemArg,
)

let fullQueryGenerator* {.compileTime.} = newGenerator(
  ident = "FullQuery",
  interest = {Standard, Outside},
  generate = generate,
  worldFields = worldFields,
  systemArg = fullQuerySystemArg,
)
