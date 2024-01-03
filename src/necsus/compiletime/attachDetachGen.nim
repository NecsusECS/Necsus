import macros, sequtils
import tools, tupleDirective, commonVars, queryGen, lookupGen, spawnGen
import archetype, componentDef, worldEnum, systemGen, archetypeBuilder
import ../runtime/[world, archetypeStore, directives], ../util/bits

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

proc isAttachable(gen: DirectiveGen): bool =
    ## Returns whether this argument produces an entity that can be attached to
    gen == queryGenerator or gen == lookupGenerator or gen == spawnGenerator

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
        let appStateTypeName = details.appStateTypeName

        # Generate a cases statement to do the work for each kind of archetype
        var cases: NimNode = newEmptyNode()
        if details.archetypes.len > 0:
            var needsElse = false
            cases = nnkCaseStmt.newTree(newDotExpr(entityIndex, ident("archetype")))
            for (ofBranch, fromArch) in archetypeCases(details):
                let toArch = fromArch + attach.comps
                if fromArch == toArch:
                    cases.add(nnkOfBranch.newTree(ofBranch, details.createArchUpdate(attach, toArch)))
                elif toArch in details.archetypes:
                    cases.add(nnkOfBranch.newTree(ofBranch, details.createArchMove(attach, fromArch, toArch)))
                else:
                    needsElse = true
            if needsElse:
                cases.add(nnkElse.newTree(nnkDiscardStmt.newTree(newEmptyNode())))

        return quote do:
            proc `attachProc`(
                `appStateIdent`: var `appStateTypeName`,
                `entityId`: EntityId,
                `newComps`: `componentTuple`
            ) =
                var `entityIndex` = `appStateIdent`.`worldIdent`[`entityId`]
                `cases`
    of Standard:
        let procName = ident(name)
        return quote:
            `appStateIdent`.`procName` = proc(`entityId`: EntityId, `newComps`: `componentTuple`) =
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

        var cases = newEmptyNode()
        if details.archetypes.len > 0:
            var needsElse = false
            cases = nnkCaseStmt.newTree(newDotExpr(entityIndex, ident("archetype")))
            for (ofBranch, fromArch) in archetypeCases(details):
                if fromArch.containsAllOf(detach.comps):
                    let toArch = fromArch - detach.comps
                    cases.add(nnkOfBranch.newTree(ofBranch, details.createArchMove(detach, fromArch, toArch)))
                else:
                    needsElse = true

            if needsElse:
                cases.add(nnkElse.newTree(nnkDiscardStmt.newTree(newEmptyNode())))

        return quote:
            proc `detachProc`(`appStateIdent`: var `appStateTypeName`, `entityId`: EntityId) =
                let `entityIndex` = `appStateIdent`.`worldIdent`[`entityId`]
                `cases`

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
