import tables, macros
import tupleDirective, archetype, componentDef, tools, systemGen, archetypeBuilder, commonVars
import ../runtime/[archetypeStore, query], ../util/bits

iterator selectArchetypes(details: GenerateContext, query: TupleDirective): Archetype[ComponentDef] =
    ## Iterates through the archetypes that contribute to a query
    for archetype in details.archetypes:
        if archetype.bitset.matches(query.filter):
            yield archetype

let slot {.compileTime.} = ident("slot")
let entry {.compileTime.} = ident("entry")

proc walkArchetypes(
    details: GenerateContext,
    name: string,
    query: TupleDirective,
    queryTupleType: NimNode,
): (NimNode, NimNode) =
    ## Creates the views that bind an archetype to a query
    var lenCalculation = newLit(0'u)
    var iteratorBody = newStmtList()

    for archetype in details.selectArchetypes(query):
        let archetypeIdent = archetype.ident
        let tupleCopy = newDotExpr(entry, ident("components")).copyTuple(archetype, query)

        lenCalculation = quote do:
            `lenCalculation` + len(`appStateIdent`.`archetypeIdent`)

        iteratorBody.add quote do:
            for `entry` in items(`appStateIdent`.`archetypeIdent`):
                `slot` = `tupleCopy`
                yield `entry`.entityId

    return (lenCalculation, iteratorBody)

proc worldFields(name: string, dir: TupleDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("RawQuery"), dir.asTupleType)) ]


proc systemArg(queryType: NimNode, name: string, dir: TupleDirective): NimNode =
    let nameIdent = name.ident
    let tupleType = dir.args.asTupleType
    return quote:
        `queryType`[`tupleType`](addr `appStateIdent`.`nameIdent`)

proc querySystemArg(name: string, dir: TupleDirective): NimNode = systemArg(bindSym("Query"), name, dir)

proc fullQuerySystemArg(name: string, dir: TupleDirective): NimNode = systemArg(bindSym("FullQuery"), name, dir)

let appStatePtr {.compileTime.} = ident("appStatePtr")

proc generate(details: GenerateContext, arg: SystemArg, name: string, dir: TupleDirective): NimNode =
    ## Generates the code for instantiating queries

    let buildQueryProc = details.globalName(name)

    case details.hook
    of GenerateHook.Outside:
        let appStateTypeName = details.appStateTypeName
        let queryTuple = dir.args.asTupleType

        let (lenCalculation, iteratorBody) = details.walkArchetypes(name, dir, queryTuple)
        let getLen = details.globalName(name & "_getLen")
        let getIterator = details.globalName(name & "_getIterator")

        return quote do:

            func `getLen`(`appStatePtr`: pointer): uint {.fastcall.} =
                let `appStateIdent` = cast[ptr `appStateTypeName`](`appStatePtr`)
                return `lenCalculation`

            func `getIterator`(`appStatePtr`: pointer): QueryIterator[`queryTuple`] {.fastcall.} =
                let `appStateIdent` = cast[ptr `appStateTypeName`](`appStatePtr`)
                return iterator(`slot`: var `queryTuple`): EntityId = `iteratorBody`

            func `buildQueryProc`(
                `appStateIdent`: ptr `appStateTypeName`
            ): RawQuery[`queryTuple`] {.gcsafe, raises: [].} =
                return newQuery[`queryTuple`](`appStateIdent`, `getLen`, `getIterator`)

    of GenerateHook.Standard:
        let ident = name.ident
        return quote do:
            `appStateIdent`.`ident` = `buildQueryProc`(addr `appStateIdent`)
    else:
        return newEmptyNode()

let queryGenerator* {.compileTime.} = newGenerator(
    ident = "Query",
    interest = { Standard, Outside },
    generate = generate,
    worldFields = worldFields,
    systemArg = querySystemArg,
)

let fullQueryGenerator* {.compileTime.} = newGenerator(
    ident = "FullQuery",
    interest = { Standard, Outside },
    generate = generate,
    worldFields = worldFields,
    systemArg = fullQuerySystemArg,
)

