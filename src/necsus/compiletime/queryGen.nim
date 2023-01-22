import tables, macros, sequtils
import tupleDirective, archetype, componentDef, tools, systemGen, archetypeBuilder
import ../runtime/[archetypeStore, query]

proc argMatchesQuery(archetype: Archetype[ComponentDef], arg: DirectiveArg): bool =
    ## Returns whether a directive is part of an archetype
    case arg.kind
    of DirectiveArgKind.Optional: true
    of DirectiveArgKind.Include: arg.component in archetype
    of DirectiveArgKind.Exclude: arg.component notin archetype

iterator selectArchetypes(details: GenerateContext, query: TupleDirective): Archetype[ComponentDef] =
    ## Iterates through the archetypes that contribute to a query
    for archetype in details.archetypes:
        if query.args.allIt(argMatchesQuery(archetype, it)):
            yield archetype

proc createArchetypeViews(details: GenerateContext, query: TupleDirective): NimNode =
    ## Creates the views that bind an archetype to a query
    result = nnkBracket.newTree()
    for archetype in details.selectArchetypes(query):
        let archetypeIdent = archetype.ident
        let compsIdent = ident("comps")
        let tupleCopy = compsIdent.copyTuple(archetype, query)
        let archTupleType = archetype.asStorageTuple
        let queryTupleType = query.args.asTupleType
        result.add quote do:
            asView(`archetypeIdent`, proc (`compsIdent`: ptr `archTupleType`): `queryTupleType` = `tupleCopy`)

proc worldFields(name: string, dir: TupleDirective): seq[WorldField] =
     @[ (name, nnkBracketExpr.newTree(bindSym("Query"), dir.asTupleType)) ]

proc generateTuple(details: GenerateContext, dir: TupleDirective): NimNode =
    ## Generates the code for instantiating queries
    result = newStmtList()
    case details.hook
    of GenerateHook.Standard:
        let ident = details.name.ident
        let queryTuple = dir.args.toSeq.asTupleType
        let views = details.createArchetypeViews(dir)
        result.add quote do:
            var `ident` = newQuery[`queryTuple`](@`views`)
    else:
        discard

let queryGenerator* {.compileTime.} = newGenerator("Query", generateTuple, worldFields = worldFields)

