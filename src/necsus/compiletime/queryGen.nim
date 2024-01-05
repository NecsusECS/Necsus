import tables, macros
import tupleDirective, archetype, componentDef, tools, systemGen, archetypeBuilder, commonVars
import ../runtime/[archetypeStore, query], ../util/bits

iterator selectArchetypes(details: GenerateContext, query: TupleDirective): Archetype[ComponentDef] =
    ## Iterates through the archetypes that contribute to a query
    for archetype in details.archetypes:
        if archetype.bitset.matches(query.filter):
            yield archetype

let compsIdent {.compileTime.} = ident("comps")

proc createArchetypeViews(
    details: GenerateContext,
    name: string,
    query: TupleDirective,
    queryTupleType: NimNode,
    dependencies: var NimNode
): NimNode =
    ## Creates the views that bind an archetype to a query
    result = nnkBracket.newTree()
    for archetype in details.selectArchetypes(query):
        let archetypeIdent = archetype.ident
        let tupleCopy = compsIdent.copyTuple(archetype, query)
        let archTupleType = archetype.asStorageTuple
        let convertProcName = details.globalName("converter_" & archetype.ident.strVal & "_" & name)

        dependencies.add quote do:
            func `convertProcName`(`compsIdent`: ptr `archTupleType`): `queryTupleType` = `tupleCopy`

        result.add quote do:
            asView(`appStateIdent`.`archetypeIdent`, `convertProcName`)

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
        var output = newStmtList()
        let appStateTypeName = details.appStateTypeName
        let queryTuple = dir.args.asTupleType
        let views = details.createArchetypeViews(name, dir, queryTuple, output)
        output.add quote do:
            func `buildQueryProc`(`appStateIdent`: var `appStateTypeName`): auto = newQuery[`queryTuple`](@`views`)
        return output

    of GenerateHook.Standard:
        let ident = name.ident
        return quote do:
            `appStateIdent`.`ident` = `buildQueryProc`(`appStateIdent`)
    else:
        return newEmptyNode()

let queryGenerator* {.compileTime.} = newGenerator(
    ident = "Query",
    interest = { Standard, Outside },
    generate = generate,
    worldFields = worldFields,
    systemArg = systemArg,
)

