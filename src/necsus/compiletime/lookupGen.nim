import macros, sequtils, options
import codeGenInfo, tupleDirective, tools, directiveSet, commonVars, archetype, componentDef, worldEnum

let entityId {.compileTime.} = ident("entityId")

let entityIndex {.compileTime.} = ident("entityIndex")

proc buildArchetypeLookup(codeGenInfo: CodeGenInfo, lookup: LookupDef, archetype: Archetype[ComponentDef]): NimNode =
    ## Builds the block of code for pulling a lookup out of a specific archetype

    let archetypeType = archetype.asStorageTuple
    let archetypeIdent = archetype.ident
    let archetypeEnum = codeGenInfo.archetypeEnum.enumSymbol
    let compsIdent = ident("comps")
    let createTuple = compsIdent.copyTuple(archetype.items.toSeq, lookup.args)

    return quote do:
        let `compsIdent` = getComps[`archetypeEnum`, `archetypeType`](`archetypeIdent`, `entityIndex`.archetypeIndex)
        return some(`createTuple`)

proc canCreateFrom(lookup: LookupDef, archetype: Archetype[ComponentDef]): bool =
    ## Returns whether a lookup can be created from an archetype
    lookup.items.toSeq.allIt(it in archetype)

proc createLookupProc(codeGenInfo: CodeGenInfo, name: string, lookup: LookupDef): NimNode =
    ## Create the proc for performing a single lookup

    let procName = ident(name)
    let tupleType = lookup.args.toSeq.asTupleType

    # Create a case statement where each branch is one of the archetypes
    let archetypeCases = nnkCaseStmt.newTree(newDotExpr(entityIndex, ident("archetype")))
    for archetype in codeGenInfo.archetypes:
        if lookup.canCreateFrom(archetype):
            archetypeCases.add(
                nnkOfBranch.newTree(
                    codeGenInfo.archetypeEnum.enumRef(archetype),
                    buildArchetypeLookup(codeGenInfo, lookup, archetype)
                )
            )

    if codeGenInfo.archetypes.anyIt(not canCreateFrom(lookup, it)):
        archetypeCases.add(nnkElse.newTree(nnkReturnStmt.newTree(newCall(bindSym("none"), tupleType))))

    return quote:
        proc `procName`(`entityId`: EntityId): Option[`tupleType`] =
            let `entityIndex` = `worldIdent`[`entityId`]
            `archetypeCases`

proc createLookups*(codeGenInfo: CodeGenInfo): NimNode =
    # Creates the methods needed to look up an entity
    result = newStmtList()
    for (name, lookup) in codeGenInfo.lookups:
        result.add(codeGenInfo.createLookupProc(name, lookup))
