import macros, sequtils
import tools, tupleDirective, dualDirective, commonVars, queryGen, lookupGen, spawnGen
import archetype, componentDef, worldEnum, systemGen, archetypeBuilder
import ../runtime/[world, archetypeStore, directives], ../util/bits

let entityIndex {.compileTime.} = ident("entityIndex")
let newComps {.compileTime.} = ident("comps")
let entityId {.compileTime.} = ident("entityId")

proc createArchUpdate(
    details: GenerateContext,
    attachComps: seq[ComponentDef],
    archetype: Archetype[ComponentDef]
): NimNode =
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

    for i, component in attachComps:
        let storageIndex = archetype.indexOf(component)
        result.add quote do:
            `existing`[`storageIndex`] = `newComps`[`i`]

proc createArchMove(
    details: GenerateContext,
    newCompValues: seq[ComponentDef],
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
        if comp in newCompValues:
            createNewTuple.add(nnkBracketExpr.newTree(newComps, newLit(newCompValues.find(comp))))
        else:
            createNewTuple.add(nnkBracketExpr.newTree(existing, newLit(fromArch.indexOf(comp))))

    return quote:
        moveEntity[`archetypeEnum`, `fromArchTuple`, `toArchTuple`](
            `appStateIdent`.`worldIdent`, `entityIndex`, `appStateIdent`.`fromArchIdent`, `appStateIdent`.`toArchIdent`,
            proc (`existing`: sink `fromArchTuple`): auto {.gcsafe, raises: [].} = `createNewTuple`
        )

proc attachDetachProcBody(
    details: GenerateContext,
    attachComps: seq[ComponentDef],
    detachComps: seq[ComponentDef]
): NimNode =
    ## Generates the logic needed to attach and detach components from an existing entity

    # Generate a cases statement to do the work for each kind of archetype
    var cases: NimNode = newEmptyNode()
    if details.archetypes.len > 0:
        var needsElse = false
        cases = nnkCaseStmt.newTree(newDotExpr(entityIndex, ident("archetype")))
        for (ofBranch, fromArch) in archetypeCases(details):
            if detachComps.len == 0 or fromArch.containsAllOf(detachComps):
                let toArch = fromArch + attachComps - detachComps
                if fromArch == toArch:
                    if attachComps.len > 0:
                        cases.add(nnkOfBranch.newTree(ofBranch, details.createArchUpdate(attachComps, toArch)))
                    else:
                        needsElse = true
                elif toArch in details.archetypes:
                    cases.add(nnkOfBranch.newTree(ofBranch, details.createArchMove(attachComps, fromArch, toArch)))
                else:
                    needsElse = true
            else:
                needsElse = true
        if needsElse:
            cases.add(nnkElse.newTree(nnkDiscardStmt.newTree(newEmptyNode())))

    return quote do:
        var `entityIndex` {.used.} = `appStateIdent`.`worldIdent`[`entityId`]
        `cases`

proc isAttachable(gen: DirectiveGen): bool =
    ## Returns whether this argument produces an entity that can be attached to
    gen == fullQueryGenerator or gen == lookupGenerator or gen == fullSpawnGenerator

proc attachArchetype(builder: var ArchetypeBuilder[ComponentDef], systemArgs: seq[SystemArg], dir: TupleDirective) =
    for arg in systemArgs.allArgs:
        if arg.generator.isAttachable:
            builder.attachable(dir.comps, arg.tupleDir.filter)

proc attachFields(name: string, dir: TupleDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("Attach"), dir.asTupleType)) ]

proc generateAttach(details: GenerateContext, arg: SystemArg, name: string, attach: TupleDirective): NimNode =
    ## Generates the code for instantiating queries
    let attachProc = details.globalName(name)
    let componentTuple = attach.args.asTupleType

    case details.hook
    of Outside:
        let `body` = details.attachDetachProcBody(attach.comps, @[])
        let appStateTypeName = details.appStateTypeName
        return quote do:
            proc `attachProc`(
                `appStateIdent`: var `appStateTypeName`,
                `entityId`: EntityId,
                `newComps`: `componentTuple`
            ) {.gcsafe, raises: [].} =
                `body`
    of Standard:
        let procName = ident(name)
        return quote:
            `appStateIdent`.`procName` = proc(`entityId`: EntityId, `newComps`: `componentTuple`) {.gcsafe, raises: [].} =
                `attachProc`(`appStateIdent`, `entityId`, `newComps`)
    else:
        return newEmptyNode()

let attachGenerator* {.compileTime.} = newGenerator(
    ident = "Attach",
    interest = { Standard, Outside },
    generate = generateAttach,
    archetype = attachArchetype,
    worldFields = attachFields
)

proc detachArchetype(builder: var ArchetypeBuilder[ComponentDef], systemArgs: seq[SystemArg], dir: TupleDirective) =
    builder.detachable(dir.comps)

proc detachFields(name: string, dir: TupleDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("Detach"), dir.asTupleType)) ]

proc generateDetach(details: GenerateContext, arg: SystemArg, name: string, detach: TupleDirective): NimNode =
    ## Generates the code for instantiating queries

    let detachProc = details.globalName(name)

    case details.hook
    of GenerateHook.Outside:
        let appStateTypeName = details.appStateTypeName
        let body = details.attachDetachProcBody(@[], detach.comps)
        return quote:
            proc `detachProc`(`appStateIdent`: var `appStateTypeName`, `entityId`: EntityId) =
                `body`

    of GenerateHook.Standard:
        let procName = ident(name)
        return quote:
            `appStateIdent`.`procName` = proc(`entityId`: EntityId) =
                `detachProc`(`appStateIdent`, `entityId`)
    else:
        return newEmptyNode()

let detachGenerator* {.compileTime.} = newGenerator(
    ident = "Detach",
    interest = { Standard, Outside },
    generate = generateDetach,
    archetype = detachArchetype,
    worldFields = detachFields,
)

proc generateSwap(details: GenerateContext, arg: SystemArg, name: string, dir: DualDirective): NimNode =
    ## Generates the code for instantiating queries
    let swapProc = details.globalName(name)
    let componentTuple = dir.first.asTupleType

    case details.hook
    of Outside:
        let `body` = details.attachDetachProcBody(dir.first, dir.second)
        let appStateTypeName = details.appStateTypeName
        return quote do:
            proc `swapProc`(
                `appStateIdent`: var `appStateTypeName`,
                `entityId`: EntityId,
                `newComps`: `componentTuple`
            ) {.gcsafe, raises: [].} =
                `body`
    of Standard:
        let procName = ident(name)
        return quote:
            `appStateIdent`.`procName` = proc(`entityId`: EntityId, `newComps`: `componentTuple`) {.gcsafe, raises: [].} =
                `swapProc`(`appStateIdent`, `entityId`, `newComps`)
    else:
        return newEmptyNode()

proc swapArchetype(builder: var ArchetypeBuilder[ComponentDef], systemArgs: seq[SystemArg], dir: DualDirective) =
    for arg in systemArgs.allArgs:
        if arg.generator.isAttachable:
            builder.attachDetach(dir.first, dir.second, arg.tupleDir.filter)

proc swapFields(name: string, dir: DualDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("Swap"), dir.first.asTupleType, dir.second.asTupleType)) ]

let swapGenerator* {.compileTime.} = newGenerator(
    ident = "Swap",
    interest = { Outside, Standard },
    generate = generateSwap,
    archetype = swapArchetype,
    worldFields = swapFields,
)
