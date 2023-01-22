import macros, sequtils, options, tables
import tupleDirective, tools, commonVars, archetype, componentDef, worldEnum, systemGen
import ../runtime/[world, archetypeStore, directives]

let entityId {.compileTime.} = ident("entityId")

let entityIndex {.compileTime.} = ident("entityIndex")

proc buildArchetypeLookup(
    details: GenerateContext,
    lookup: TupleDirective,
    archetype: Archetype[ComponentDef]
): NimNode =
    ## Builds the block of code for pulling a lookup out of a specific archetype

    let archetypeType = archetype.asStorageTuple
    let archetypeIdent = archetype.ident
    let archetypeEnum = details.archetypeEnum.ident
    let compsIdent = ident("comps")
    let createTuple = compsIdent.copyTuple(archetype, lookup)

    return quote do:
        let `compsIdent` = getComps[`archetypeEnum`, `archetypeType`](
            `appStateIdent`.`archetypeIdent`, 
            `entityIndex`.archetypeIndex
        )
        return some(`createTuple`)

proc worldFields(name: string, dir: TupleDirective): seq[WorldField] =
     @[ (name, nnkBracketExpr.newTree(bindSym("Lookup"), dir.asTupleType)) ]

proc canCreateFrom(lookup: TupleDirective, archetype: Archetype[ComponentDef]): bool =
    ## Returns whether a lookup can be created from an archetype
    lookup.items.toSeq.allIt(it in archetype)

proc generateTuple(details: GenerateContext, lookup: TupleDirective): NimNode =
    ## Generates the code for instantiating queries
    case details.hook
    of GenerateHook.Standard:

        let procName = ident(details.name)
        let tupleType = lookup.args.toSeq.asTupleType

        # Create a case statement where each branch is one of the archetypes
        let cases = details.createArchetypeCase(newDotExpr(entityIndex, ident("archetype"))) do (fromArch: auto) -> auto:
            if lookup.canCreateFrom(fromArch):
                details.buildArchetypeLookup(lookup, fromArch)
            else:
                quote: return none(`tupleType`)

        return quote:
            `appStateIdent`.`procName` = proc(`entityId`: EntityId): Option[`tupleType`] =
                let `entityIndex` = `appStateIdent`.`worldIdent`[`entityId`]
                `cases`
    else:
        return newEmptyNode()

let lookupGenerator* {.compileTime.} = newGenerator(
    ident = "Lookup", 
    generate = generateTuple,
    worldFields = worldFields,
)