import macros, sequtils, tables
import tupleDirective, tools, common, archetype, componentDef, systemGen
import ../runtime/[world, archetypeStore, directives]

let entityId {.compileTime.} = ident("entityId")
let entityIndex {.compileTime.} = ident("entityIndex")
let compsIdent {.compileTime.} = ident("comps")
let output {.compileTime.} = ident("output")

proc buildArchetypeLookup(
    details: GenerateContext,
    lookup: TupleDirective,
    archetype: Archetype[ComponentDef]
): NimNode =
    ## Builds the block of code for pulling a lookup out of a specific archetype

    let archetypeType = archetype.asStorageTuple
    let archetypeIdent = archetype.ident
    let convert = newConverter(archetype, lookup).name

    return quote do:
        let `compsIdent` = getComps[`archetypeType`](
            `appStateIdent`.`archetypeIdent`,
            `entityIndex`.archetypeIndex
        )
        return `convert`(`compsIdent`, nil, `output`)

proc worldFields(name: string, dir: TupleDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("Lookup"), dir.asTupleType)) ]

proc converters(ctx: GenerateContext, dir: TupleDirective): seq[ConverterDef] =
    for archetype in ctx.archetypes:
        if archetype.matches(dir.filter):
            result.add(newConverter(archetype, dir))

proc generate(details: GenerateContext, arg: SystemArg, name: string, lookup: TupleDirective): NimNode =
    ## Generates the code for instantiating queries

    let lookupProc = details.globalName(name)
    let tupleType = lookup.args.toSeq.asTupleType

    case details.hook
    of GenerateHook.Outside:
        let appStateTypeName = details.appStateTypeName

        var cases: NimNode = newEmptyNode()
        if not isFastCompileMode(fastLookup):
            if details.archetypes.len > 0:
                cases = nnkCaseStmt.newTree(newDotExpr(entityIndex, ident("archetype")))

                # Create a case statement where each branch is one of the archetypes
                for (ofBranch, archetype) in archetypeCases(details):
                    if archetype.matches(lookup.filter):
                        cases.add(nnkOfBranch.newTree(ofBranch, details.buildArchetypeLookup(lookup, archetype)))

                # Add a fall through 'else' branch for any archetypes that don't fit this lookup
                cases.add(nnkElse.newTree(nnkReturnStmt.newTree(newLit(false))))

        return quote:
            proc `lookupProc`(
                `appStateIdent`: pointer,
                `entityId`: EntityId,
                `output`: var `tupleType`,
            ): bool {.fastcall, gcsafe, raises: [], used.} =
                var `appStateIdent` = cast[ptr `appStateTypeName`](`appStateIdent`)
                let `entityIndex` {.used.} = `appStateIdent`.`worldIdent`[`entityId`]
                `cases`

    of GenerateHook.Standard:
        let procName = ident(name)
        return quote:
            `appStateIdent`.`procName` = newCallbackDir(`appStatePtr`, `lookupProc`)
    else:
        return newEmptyNode()

let lookupGenerator* {.compileTime.} = newGenerator(
    ident = "Lookup",
    interest = { Standard, Outside },
    generate = generate,
    worldFields = worldFields,
    converters = converters,
)