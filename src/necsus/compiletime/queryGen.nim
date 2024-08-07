import std/[tables, macros, options]
import tupleDirective, archetype, componentDef, tools, systemGen, archetypeBuilder, common, directiveArg
import ../runtime/[archetypeStore, query], ../util/bits

iterator selectArchetypes(details: GenerateContext, query: TupleDirective): Archetype[ComponentDef] =
    ## Iterates through the archetypes that contribute to a query
    for archetype in details.archetypes:
        if archetype.matches(query.filter):
            yield archetype

let slot {.compileTime.} = ident("slot")
let iter {.compileTime.} = ident("iter")
let eid {.compileTime.} = ident("eid")

proc addLenPredicate(append: var NimNode, row: NimNode, arch: Archetype[ComponentDef], arg: DirectiveArg, fn: NimNode) =
    let index = arch.indexOf(arg.component).newLit
    append.add(newCall(fn, nnkBracketExpr.newTree(row, index)))

proc buildAddLen(query: TupleDirective, archetype: Archetype[ComponentDef]): NimNode =
    ## Builds the code for calculating the length of an archetype

    let archetypeIdent = archetype.ident

    # Builds a predicate that is able to determine whether a row should be counted against the length of a query.
    # This is needed because accessories are optional and not specifically tracked
    if query.hasAccessories:
        let row = genSym(nskParam, "row")

        var predicateList = nnkBracketExpr.newTree()
        for arg in query.args:
            if arg.isAccessory:
                case arg.kind
                of Optional: discard
                of Include: predicateList.addLenPredicate(row, archetype, arg, bindSym("isSome"))
                of Exclude: predicateList.addLenPredicate(row, archetype, arg, bindSym("isNone"))

        if predicateList.len > 0:
            let symbol = genSym(nskProc, "filter")
            let rowType = archetype.asStorageTuple
            let predicates = nestList(bindSym("and"), predicateList)
            return quote:
                proc `symbol`(`row`: var `rowType`): bool {.fastcall, gcsafe, raises: [].} =
                    return `predicates`

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
    var nextEntityBody = nnkCaseStmt.newTree(newDotExpr(iter, "continuationIdx".ident))

    var index = 0
    for archetype in details.selectArchetypes(query):

        lenCalculation.add(buildAddLen(query, archetype))

        let archetypeIdent = archetype.ident
        let copier = newConverter(archetype, query).name
        let nextBody = quote do:
            result = `copier`(`appStateIdent`.`archetypeIdent`.next(`iter`, `eid`), nil, `slot`).asNextIterState

        nextEntityBody.add nnkOfBranch.newTree(newLit(index), nextBody)
        index += 1

    nextEntityBody.add nnkElse.newTree quote do:
        result = DoneIter

    return (lenCalculation, nextEntityBody)

proc worldFields(name: string, dir: TupleDirective): seq[WorldField] =
    @[ (name, bindSym("RawQuery")) ]


proc systemArg(queryType: NimNode, name: string, dir: TupleDirective): NimNode =
    let nameIdent = name.ident
    let tupleType = dir.args.asTupleType
    return quote:
        `queryType`[`tupleType`](addr `appStateIdent`.`nameIdent`)

proc querySystemArg(name: string, dir: TupleDirective): NimNode = systemArg(bindSym("Query"), name, dir)

proc fullQuerySystemArg(name: string, dir: TupleDirective): NimNode = systemArg(bindSym("FullQuery"), name, dir)

proc converters(ctx: GenerateContext, dir: TupleDirective): seq[ConverterDef] =
    for archetype in ctx.selectArchetypes(dir):
        result.add(newConverter(archetype, dir))

let appStatePtr {.compileTime, used.} = ident("appStatePtr")

proc generate(details: GenerateContext, arg: SystemArg, name: string, dir: TupleDirective): NimNode =
    ## Generates the code for instantiating queries
    if isFastCompileMode(fastQueryGen):
        return newEmptyNode()

    let queryTuple = dir.args.asTupleType
    let getLen = details.globalName(name & "_getLen")
    let nextEntity = details.globalName(name & "_nextEntity")

    case details.hook
    of GenerateHook.Outside:
        let appStateTypeName = details.appStateTypeName

        let (lenCalculation, nextEntityBody) = details.walkArchetypes(name, dir, queryTuple)

        let trace = emitQueryTrace("Query for ", dir.name, " returned ", newCall(getLen, appStatePtr), " result(s)")
        let log = if trace.kind != nnkEmpty:
            quote:
                if `iter`.isFirst:
                    `trace`
        else:
            newEmptyNode()

        return quote do:

            proc `getLen`(`appStatePtr`: pointer): uint {.fastcall.} =
                let `appStateIdent` {.used.} = cast[ptr `appStateTypeName`](`appStatePtr`)
                result = 0
                `lenCalculation`

            proc `nextEntity`(
                `iter`: var QueryIterator, `appStatePtr`: pointer, `eid`: var EntityId, `slot`: var `queryTuple`
            ): NextIterState {.gcsafe, raises: [], fastcall.} =
                let `appStateIdent` {.used.} = cast[ptr `appStateTypeName`](`appStatePtr`)
                `log`
                `nextEntityBody`

    of GenerateHook.Standard:
        let ident = name.ident
        return quote do:
            `appStateIdent`.`ident` = newQuery[`queryTuple`](addr `appStateIdent`, `getLen`, `nextEntity`)
    else:
        return newEmptyNode()

let queryGenerator* {.compileTime.} = newGenerator(
    ident = "Query",
    interest = { Standard, Outside },
    generate = generate,
    worldFields = worldFields,
    systemArg = querySystemArg,
    converters = converters,
)

let fullQueryGenerator* {.compileTime.} = newGenerator(
    ident = "FullQuery",
    interest = { Standard, Outside },
    generate = generate,
    worldFields = worldFields,
    systemArg = fullQuerySystemArg,
    converters = converters,
)

