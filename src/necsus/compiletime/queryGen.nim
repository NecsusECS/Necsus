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

proc systemArg(name: string, dir: TupleDirective): NimNode =
    let nameIdent = name.ident
    return quote:
        addr `appStateIdent`.`nameIdent`

proc generate(details: GenerateContext, arg: SystemArg, name: string, dir: TupleDirective): NimNode =
    ## Generates the code for instantiating queries

    let buildQueryProc = details.globalName(name)

    case details.hook
    of GenerateHook.Outside:
        let appStateTypeName = details.appStateTypeName
        let queryTuple = dir.args.asTupleType

        let (lenCalculation, iteratorBody) = details.walkArchetypes(name, dir, queryTuple)

        return quote do:
            func `buildQueryProc`(`appStateIdent`: ptr `appStateTypeName`): RawQuery[`queryTuple`] =
                proc getLen(): uint = `lenCalculation`
                proc getIterator(): QueryIterator[`queryTuple`] =
                    return iterator(`slot`: var `queryTuple`): EntityId = `iteratorBody`
                return newQuery[`queryTuple`](getLen, getIterator)

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
    systemArg = systemArg,
)

