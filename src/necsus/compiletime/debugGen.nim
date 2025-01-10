import macros, options, tables
import tools, common, archetype, componentDef, systemGen
import ../runtime/[world, archetypeStore, directives], ../util/tools

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

    let archetypeIdentVar = newLit(" = " & archetype.readableName & " (" & archetype.idSymbol.strVal & ")")

    var str = quote do:
        $`entityId` & `archetypeIdentVar`

    var i = 0
    for comp in archetype:
        let label = newLit("; " & comp.readableName & " = ")
        str = quote:
            `str` & `label` & stringify(`compsIdent`[`i`])
        i += 1

    return quote do:
        let `compsIdent` = getComps[`archetypeType`](
            `appStateIdent`.`archetypeIdent`,
            `entityIndex`.archetypeIndex
        )
        return `str`

proc generateEntityDebug(details: GenerateContext, arg: SystemArg, name: string): NimNode =
    ## Generates the code for debugging the state of an entity
    if isFastCompileMode(fastDebugGen):
        return newEmptyNode()

    let debugProc = details.globalName(name)

    case details.hook
    of GenerateHook.Outside:
        let appType = details.appStateTypeName

        # Create a case statement where each branch is one of the archetypes
        var cases = newEmptyNode()

        when not defined(release):
            if details.archetypes.len > 0:
                cases = nnkCaseStmt.newTree(entityArchetype)
                for (ofBranch, archetype) in archetypeCases(details):
                    cases.add(nnkOfBranch.newTree(ofBranch, details.buildArchetypeLookup(archetype)))
                cases.add(nnkElse.newTree(nnkDiscardStmt.newTree(newEmptyNode())))

        return quote:

            proc `debugProc`(
                `appStatePtr`: pointer,
                `entityId`: EntityId
            ): string {.nimcall, gcsafe, raises: [Exception].} =
                let `appStateIdent` {.used.} = cast[ptr `appType`](`appStatePtr`)
                let `entityIndex` {.used.} = `appStateIdent`.`worldIdent`[`entityId`]

                if unlikely(`entityIndex` == nil):
                    return "No such entity: " & $`entityId`
                else:
                    `cases`

    of GenerateHook.Standard:
        let procName = ident(name)
        return quote:
            `appStateIdent`.`procName` = newCallbackDir(`appStatePtr`, `debugProc`)
    else:
        return newEmptyNode()

let entityDebugGenerator* {.compileTime.} = newGenerator(
    ident = "EntityDebug",
    interest = { Standard, Outside },
    generate = generateEntityDebug,
    worldFields = worldFields,
)
