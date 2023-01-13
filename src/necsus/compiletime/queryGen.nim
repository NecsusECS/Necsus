import tables, macros, sequtils
import codeGenInfo, directiveSet, tupleDirective, archetype, componentDef, tools
import ../runtime/archetypeStore

proc argMatchesQuery(archetype: Archetype[ComponentDef], arg: DirectiveArg): bool =
    ## Returns whether a directive is part of an archetype
    case arg.kind
    of DirectiveArgKind.Optional: true
    of DirectiveArgKind.Include: arg.component in archetype
    of DirectiveArgKind.Exclude: arg.component notin archetype

iterator selectArchetypes(codeGenInfo: CodeGenInfo, query: QueryDef): Archetype[ComponentDef] =
    ## Iterates through the archetypes that contribute to a query
    for archetype in codeGenInfo.archetypes:
        if query.args.allIt(argMatchesQuery(archetype, it)):
            yield archetype

proc createArchetypeViews(codeGenInfo: CodeGenInfo, query: QueryDef): NimNode =
    ## Creates the views that bind an archetype to a query
    result = nnkBracket.newTree()
    for archetype in selectArchetypes(codeGenInfo, query):
        let archetypeIdent = archetype.ident
        let compsIdent = ident("comps")
        let tupleCopy = compsIdent.copyTuple(archetype, query)
        let archTupleType = archetype.asStorageTuple
        let queryTupleType = query.args.asTupleType
        result.add quote do:
            asView(`archetypeIdent`, proc (`compsIdent`: ptr `archTupleType`): `queryTupleType` = `tupleCopy`)

proc createQueryInstances*(codeGenInfo: CodeGenInfo): NimNode =
    ## Creates the variables required for running a query
    result = newStmtList()

    for (name, queryDef) in codeGenInfo.queries:
        let ident = name.ident
        let queryTuple = queryDef.args.toSeq.asTupleType
        let views = codeGenInfo.createArchetypeViews(queryDef)
        result.add quote do:
            var `ident` = newQuery[`queryTuple`](@`views`)
