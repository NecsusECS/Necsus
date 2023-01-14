import macros, sequtils, options, tables
import codeGenInfo, tupleDirective, tools, directiveSet, commonVars, archetype, componentDef, worldEnum
import ../runtime/[world, archetypeStore]

let entityId {.compileTime.} = ident("entityId")

let entityIndex {.compileTime.} = ident("entityIndex")

proc buildArchetypeLookup(codeGenInfo: CodeGenInfo, lookup: LookupDef, archetype: Archetype[ComponentDef]): NimNode =
    ## Builds the block of code for pulling a lookup out of a specific archetype

    let archetypeType = archetype.asStorageTuple
    let archetypeIdent = archetype.ident
    let archetypeEnum = codeGenInfo.archetypeEnum.enumSymbol
    let compsIdent = ident("comps")
    let createTuple = compsIdent.copyTuple(archetype, lookup)

    return quote do:
        let `compsIdent` = getComps[`archetypeEnum`, `archetypeType`](`archetypeIdent`, `entityIndex`.archetypeIndex)
        return some(`createTuple`)

proc canCreateFrom(lookup: LookupDef, archetype: Archetype[ComponentDef]): bool =
    ## Returns whether a lookup can be created from an archetype
    lookup.items.toSeq.allIt(it in archetype)

proc createLookupProc(genInfo: CodeGenInfo, name: string, lookup: LookupDef): NimNode =
    ## Create the proc for performing a single lookup

    let procName = ident(name)
    let tupleType = lookup.args.toSeq.asTupleType

    # Create a case statement where each branch is one of the archetypes
    let cases = genInfo.createArchetypeCase(newDotExpr(entityIndex, ident("archetype"))) do (fromArch: auto) -> auto:
        if lookup.canCreateFrom(fromArch):
            genInfo.buildArchetypeLookup(lookup, fromArch)
        else:
            quote: return none(`tupleType`)

    return quote:
        proc `procName`(`entityId`: EntityId): Option[`tupleType`] =
            let `entityIndex` = `worldIdent`[`entityId`]
            `cases`

proc createLookups*(codeGenInfo: CodeGenInfo): NimNode =
    # Creates the methods needed to look up an entity
    result = newStmtList()
    for (name, lookup) in codeGenInfo.lookups:
        result.add(codeGenInfo.createLookupProc(name, lookup))
