import macros, sequtils, options, tables
import tupleDirective, tools, commonVars, archetype, componentDef, worldEnum, systemGen
import ../runtime/[world, archetypeStore, directives]

let entityId {.compileTime.} = ident("entityId")

let entityIndex {.compileTime.} = ident("entityIndex")

let compsIdent {.compileTime.} = ident("comps")

proc buildArchetypeLookup(
    details: GenerateContext,
    lookup: TupleDirective,
    archetype: Archetype[ComponentDef]
): NimNode =
    ## Builds the block of code for pulling a lookup out of a specific archetype

    let archetypeType = archetype.asStorageTuple
    let archetypeIdent = archetype.ident
    let archetypeEnum = details.archetypeEnum.ident
    let createTuple = compsIdent.copyTuple(archetype, lookup)

    return quote do:
        let `compsIdent` = getComps[`archetypeEnum`, `archetypeType`](
            `appStateIdent`.`archetypeIdent`,
            `entityIndex`.archetypeIndex
        )
        result = some(`createTuple`)

proc worldFields(name: string, dir: TupleDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("Lookup"), dir.asTupleType)) ]

proc canCreateFrom(lookup: TupleDirective, archetype: Archetype[ComponentDef]): bool =
    ## Returns whether a lookup can be created from an archetype
    lookup.items.toSeq.allIt(it in archetype)

proc generate(details: GenerateContext, arg: SystemArg, name: string, lookup: TupleDirective): NimNode =
    ## Generates the code for instantiating queries

    let lookupProc = details.globalName(name)
    let tupleType = lookup.args.toSeq.asTupleType

    case details.hook
    of GenerateHook.Outside:
        let appStateTypeName = details.appStateTypeName

        var cases: NimNode = newEmptyNode()
        if details.archetypes.len > 0:
            cases = nnkCaseStmt.newTree(newDotExpr(entityIndex, ident("archetype")))

            # Create a case statement where each branch is one of the archetypes
            var needsElse = false
            for (ofBranch, archetype) in archetypeCases(details):
                if lookup.canCreateFrom(archetype):
                    cases.add(nnkOfBranch.newTree(ofBranch, details.buildArchetypeLookup(lookup, archetype)))
                else:
                    needsElse = true

            # Add a fall through 'else' branch for any archetypes that don't fit this lookup
            if needsElse:
                cases.add(nnkElse.newTree(nnkDiscardStmt.newTree(newEmptyNode())))

        return quote:
            proc `lookupProc`(
                `appStateIdent`: var `appStateTypeName`, `entityId`: EntityId
            ): Option[`tupleType`] {.fastcall, gcsafe, raises: [].} =
                let `entityIndex` = `appStateIdent`.`worldIdent`[`entityId`]
                `cases`

    of GenerateHook.Standard:
        let procName = ident(name)
        return quote:
            `appStateIdent`.`procName` = proc(`entityId`: EntityId): Option[`tupleType`] =
                `lookupProc`(`appStateIdent`, `entityId`)
    else:
        return newEmptyNode()

let lookupGenerator* {.compileTime.} = newGenerator(
    ident = "Lookup",
    interest = { Standard, Outside },
    generate = generate,
    worldFields = worldFields,
)