import tables, macros
import tupleDirective, archetype, componentDef, tools, systemGen, archetypeBuilder, commonVars
import ../runtime/[archetypeStore, query], ../util/bits

iterator selectArchetypes(details: GenerateContext, query: TupleDirective): Archetype[ComponentDef] =
    ## Iterates through the archetypes that contribute to a query
    for archetype in details.archetypes:
        if archetype.bitset.matches(query.filter):
            yield archetype

let compsIdent {.compileTime.} = ident("comps")

proc createArchetypeViews(details: GenerateContext, query: TupleDirective, queryTupleType: NimNode): NimNode =
    ## Creates the views that bind an archetype to a query
    result = nnkBracket.newTree()
    for archetype in details.selectArchetypes(query):
        let archetypeIdent = archetype.ident
        let tupleCopy = compsIdent.copyTuple(archetype, query)
        let archTupleType = archetype.asStorageTuple
        result.add quote do:
            asView(
                `appStateIdent`.`archetypeIdent`,
                proc (`compsIdent`: ptr `archTupleType`): `queryTupleType` = `tupleCopy`
            )

proc worldFields(name: string, dir: TupleDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("Query"), dir.asTupleType)) ]

proc generate(details: GenerateContext, arg: SystemArg, name: string, dir: TupleDirective): NimNode =
    ## Generates the code for instantiating queries

    let buildQueryProc = details.globalName(name)

    case details.hook
    of GenerateHook.Outside:
        let appStateTypeName = details.appStateTypeName
        let queryTuple = dir.args.asTupleType
        let views = details.createArchetypeViews(dir, queryTuple)
        return quote do:
            proc `buildQueryProc`(`appStateIdent`: var `appStateTypeName`): auto = newQuery[`queryTuple`](@`views`)

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
    worldFields = worldFields
)

