import macros, options, tables
import tools, common, archetype, componentDef, worldEnum, systemGen
import ../runtime/[world, archetypeStore, directives]

let entityId {.compileTime.} = ident("entityId")

let entityIndex {.compileTime.} = ident("entityIndex")

let compsIdent {.compileTime.} = ident("comps")

let entityArchetype {.compileTime.} = newDotExpr(entityIndex, ident("archetype"))

proc worldFields(name: string): seq[WorldField] = @[ (name, bindSym("EntityDebug")) ]

proc buildArchetypeLookup(
    details: GenerateContext,
    archetype: Archetype[ComponentDef]
): NimNode =
    ## Builds the block of code for pulling a lookup out of a specific archetype

    let archetypeType = archetype.asStorageTuple
    let archetypeIdent = archetype.ident
    let archetypeEnum = details.archetypeEnum.ident

    return quote do:
        let `compsIdent` = getComps[`archetypeEnum`, `archetypeType`](
            `appStateIdent`.`archetypeIdent`,
            `entityIndex`.archetypeIndex
        )
        return $`entityId` & " = " & $`entityArchetype` & $`compsIdent`[]

proc generateEntityDebug(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    ## Generates the code for debugging the state of an entity
    case details.hook
    of GenerateHook.Standard:

        let procName = ident(name)

        # Create a case statement where each branch is one of the archetypes
        var cases = newEmptyNode()
        if details.archetypes.len > 0:
            cases = nnkCaseStmt.newTree(entityArchetype)
            for (ofBranch, archetype) in archetypeCases(details):
                cases.add(nnkOfBranch.newTree(ofBranch, details.buildArchetypeLookup(archetype)))

        return quote:
            `appStateIdent`.`procName` = proc(`entityId`: EntityId): string =
                let `entityIndex` {.used.} = `appStateIdent`.`worldIdent`[`entityId`]
                `cases`
    else:
        return newEmptyNode()

let entityDebugGenerator* {.compileTime.} = newGenerator(
    ident = "EntityDebug",
    interest = { Standard },
    generate = generateEntityDebug,
    worldFields = worldFields,
)
