import macros, sequtils, options, tables
import tupleDirective, tools, common, archetype, componentDef, worldEnum, systemGen
import ../runtime/[world, archetypeStore, directives], ../util/bits

let entityId {.compileTime.} = ident("entityId")
let entityIndex {.compileTime.} = ident("entityIndex")
let compsIdent {.compileTime.} = ident("comps")
let output {.compileTime.} = ident("output")

proc buildArchetypeLookup(
    details: GenerateContext,
    lookup: TupleDirective,
    archetype: Archetype[ComponentDef]
): NimNode {.used.} =
    ## Builds the block of code for pulling a lookup out of a specific archetype

    let archetypeType = archetype.asStorageTuple
    let archetypeIdent = archetype.ident
    let archetypeEnum = details.archetypeEnum.ident
    let convert = details.converterName(ConverterDef(input: archetype, output: lookup))

    return quote do:
        let `compsIdent` = getComps[`archetypeEnum`, `archetypeType`](
            `appStateIdent`.`archetypeIdent`,
            `entityIndex`.archetypeIndex
        )
        `convert`(`compsIdent`, `output`)

proc worldFields(name: string, dir: TupleDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("Lookup"), dir.asTupleType)) ]

proc converters(ctx: GenerateContext, dir: TupleDirective): seq[ConverterDef] =
    for archetype in ctx.archetypes:
        if archetype.bitset.matches(dir.filter):
            result.add(ConverterDef(input: archetype, output: dir))

proc generate(details: GenerateContext, arg: SystemArg, name: string, lookup: TupleDirective): NimNode =
    ## Generates the code for instantiating queries

    let lookupProc = details.globalName(name)
    let tupleType = lookup.args.toSeq.asTupleType

    case details.hook
    of GenerateHook.Outside:
        let appStateTypeName = details.appStateTypeName

        var cases: NimNode = newEmptyNode()
        when not isFastCompileMode():
            if details.archetypes.len > 0:
                cases = nnkCaseStmt.newTree(newDotExpr(entityIndex, ident("archetype")))

                # Create a case statement where each branch is one of the archetypes
                var needsElse = false
                for (ofBranch, archetype) in archetypeCases(details):
                    if archetype.bitset.matches(lookup.filter):
                        cases.add(nnkOfBranch.newTree(ofBranch, details.buildArchetypeLookup(lookup, archetype)))
                    else:
                        needsElse = true

                # Add a fall through 'else' branch for any archetypes that don't fit this lookup
                if needsElse:
                    cases.add(nnkElse.newTree(nnkReturnStmt.newTree(newLit(false))))

        return quote:
            proc `lookupProc`(
                `appStateIdent`: var `appStateTypeName`,
                `entityId`: EntityId,
                `output`: var `tupleType`,
            ): bool {.fastcall, gcsafe, raises: [].} =
                let `entityIndex` {.used.} = `appStateIdent`.`worldIdent`[`entityId`]
                `cases`
                return true

    of GenerateHook.Standard:
        let procName = ident(name)
        return quote:
            `appStateIdent`.`procName` = proc(`entityId`: EntityId): Option[`tupleType`] =
                var `output`: `tupleType`
                if `lookupProc`(`appStateIdent`, `entityId`, `output`):
                    return some(`output`)
    else:
        return newEmptyNode()

let lookupGenerator* {.compileTime.} = newGenerator(
    ident = "Lookup",
    interest = { Standard, Outside },
    generate = generate,
    worldFields = worldFields,
    converters = converters,
)