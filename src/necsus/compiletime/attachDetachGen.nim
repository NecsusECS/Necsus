import macros, sequtils
import tools, tupleDirective, commonVars
import archetype, componentDef, worldEnum, systemGen, archetypeBuilder
import ../runtime/[world, archetypeStore, directives]

let entityIndex {.compileTime.} = ident("entityIndex")
let newComps {.compileTime.} = ident("comps")
let entityId {.compileTime.} = ident("entityId")

proc createArchUpdate(details: GenerateContext, attach: TupleDirective, archetype: Archetype[ComponentDef]): NimNode =
    ## Creates code for updating archetype information in place
    result = newStmtList()

    let archIdent = archetype.ident
    let archTuple = archetype.asStorageTuple
    let archetypeEnum = details.archetypeEnum.ident

    let existing = ident("existing")
    result.add quote do:
        let `existing` = getComps[`archetypeEnum`, `archTuple`](
            `appStateIdent`.`archIdent`,
            `entityIndex`.archetypeIndex
        )

    for i, component in attach.items.toSeq:
        let storageIndex = archetype.indexOf(component)
        result.add quote do:
            `existing`[`storageIndex`] = `newComps`[`i`]

proc createArchMove(
    details: GenerateContext,
    directive: TupleDirective,
    fromArch: Archetype[ComponentDef],
    toArch: Archetype[ComponentDef]
): NimNode =
    ## Creates code for copying from one archetype to another
    let fromArchIdent = fromArch.ident
    let fromArchTuple = fromArch.asStorageTuple
    let toArchTuple = toArch.asStorageTuple
    let toArchIdent = toArch.ident
    let archetypeEnum = details.archetypeEnum.ident
    let existing = ident("existing")

    let createNewTuple = nnkTupleConstr.newTree()
    for comp in toArch.items:
        if comp in directive:
            createNewTuple.add(nnkBracketExpr.newTree(newComps, newLit(directive.indexOf(comp))))
        else:
            createNewTuple.add(nnkBracketExpr.newTree(existing, newLit(fromArch.indexOf(comp))))

    return quote:
        moveEntity[`archetypeEnum`, `fromArchTuple`, `toArchTuple`](
            `appStateIdent`.`worldIdent`, `entityIndex`, `appStateIdent`.`fromArchIdent`, `appStateIdent`.`toArchIdent`,
            proc (`existing`: sink `fromArchTuple`): auto = `createNewTuple`
        )

proc attachArchetype(builder: var ArchetypeBuilder[ComponentDef], dir: TupleDirective) =
    builder.attachable(dir.comps)

proc attachFields(name: string, dir: TupleDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("Attach"), dir.asTupleType)) ]

proc generateAttach(details: GenerateContext, arg: SystemArg, name: string, attach: TupleDirective): NimNode =
    ## Generates the code for instantiating queries
    case details.hook
    of GenerateHook.Standard:
        let procName = ident(name)
        let componentTuple = attach.args.toSeq.asTupleType

        ## Generate a cases statement to do the work for each kind of archetype
        let cases = details.createArchetypeCase(newDotExpr(entityIndex, ident("archetype"))) do (fromArch: auto) -> auto:
            let toArch = fromArch + attach.comps
            return if fromArch == toArch:
                details.createArchUpdate(attach, toArch)
            else:
                details.createArchMove(attach, fromArch, toArch)

        return quote:
            `appStateIdent`.`procName` = proc(`entityId`: EntityId, `newComps`: `componentTuple`) =
                var `entityIndex` = `appStateIdent`.`worldIdent`[`entityId`]
                `cases`
    else:
        return newEmptyNode()

let attachGenerator* {.compileTime.} = newGenerator(
    ident = "Attach",
    interest = { Standard },
    generate = generateAttach,
    archetype = attachArchetype,
    worldFields = attachFields
)

proc detachArchetype(builder: var ArchetypeBuilder[ComponentDef], dir: TupleDirective) =
    builder.detachable(dir.comps)

proc detachFields(name: string, dir: TupleDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("Detach"), dir.asTupleType)) ]

proc generateDetach(details: GenerateContext, arg: SystemArg, name: string, detach: TupleDirective): NimNode =
    ## Generates the code for instantiating queries
    case details.hook
    of GenerateHook.Standard:

        let procName = ident(name)

        let cases = details.createArchetypeCase(newDotExpr(entityIndex, ident("archetype"))) do (fromArch: auto) -> auto:
            if fromArch.containsAllOf(detach.comps):
                let toArch = fromArch - detach.comps
                return details.createArchMove(detach, fromArch, toArch)
            else:
                return quote: discard

        return quote:
            `appStateIdent`.`procName` = proc(`entityId`: EntityId) =
                let `entityIndex` = `appStateIdent`.`worldIdent`[`entityId`]
                `cases`
    else:
        return newEmptyNode()

let detachGenerator* {.compileTime.} = newGenerator(
    ident = "Detach",
    interest = { Standard },
    generate = generateDetach,
    archetype = detachArchetype,
    worldFields = detachFields,
)
