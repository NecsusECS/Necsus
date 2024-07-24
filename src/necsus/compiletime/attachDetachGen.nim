import std/macros
import tools, tupleDirective, dualDirective, common, queryGen, lookupGen, spawnGen, directiveArg
import archetype, componentDef, worldEnum, systemGen, archetypeBuilder, converters
import ../runtime/[world, archetypeStore, directives], ../util/bits

let entityIndex {.compileTime.} = ident("entityIndex")
let newComps {.compileTime.} = ident("newComps")
let entityId {.compileTime.} = ident("entityId")

proc createArchUpdate(
    details: GenerateContext,
    title: string,
    attachComps: seq[ComponentDef],
    archetype: Archetype[ComponentDef]
): NimNode =
    ## Creates code for updating archetype information in place
    result = newStmtList(emitEntityTrace(title, " ", entityId, " for ", archetype.name))

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

proc newCompsTupleType(newCompValues: seq[ComponentDef]): NimNode =
    ## Creates the type definition to use for a tuple that represents new values passed into a convert proc
    if newCompValues.len > 0:
        return newCompValues.asTupleType
    else:
        return quote: (int, )

proc createArchMove(
    details: GenerateContext,
    title: string,
    fromArch: Archetype[ComponentDef],
    newCompValues: seq[ComponentDef],
    toArch: Archetype[ComponentDef],
    convert: ConverterDef,
): NimNode =
    ## Creates code for copying from one archetype to another
    let fromArchIdent = fromArch.ident
    let fromArchTuple = fromArch.asStorageTuple
    let toArchTuple = toArch.asStorageTuple
    let toArchIdent = toArch.ident
    let archetypeEnum = details.archetypeEnum.ident
    let convertProc = convert.name
    let newCompsType = newCompValues.newCompsTupleType()

    let newCompsArg = if newCompValues.len > 0: newComps else: quote: (0, )

    let log = emitEntityTrace(title, " ", entityId, " from ", fromArch.name, " to ", toArch.name)

    return quote:
        `log`
        moveEntity[`archetypeEnum`, `fromArchTuple`,  `newCompsType`, `toArchTuple`](
            `appStateIdent`.`worldIdent`,
            `entityIndex`,
            `appStateIdent`.`fromArchIdent`,
            `appStateIdent`.`toArchIdent`,
            `newCompsArg`,
            `convertProc`
        )

proc asBits(comps: varargs[seq[ComponentDef]]): Bits =
    result = Bits()
    for compSeq in comps:
        for comp in compSeq:
            result.incl(comp.uniqueId)

proc attachDetachProcBody(
    details: GenerateContext,
    title: string,
    attachComps: seq[ComponentDef],
    detachComps: seq[ComponentDef],
    optDetachComps: seq[ComponentDef]
): tuple[procBody: NimNode, convertProcs: NimNode] =
    ## Generates the logic needed to attach and detach components from an existing entity

    if isFastCompileMode(fastAttachDetach):
        return (newStmtList(), newStmtList())

    result.convertProcs = newStmtList()

    let toRemove = asBits(detachComps, optDetachComps)

    # Generate a cases statement to do the work for each kind of archetype
    var cases: NimNode = newEmptyNode()

    if details.archetypes.len > 0:
        var needsElse = false
        cases = nnkCaseStmt.newTree(newDotExpr(entityIndex, ident("archetype")))
        for (ofBranch, fromArch) in archetypeCases(details):
            if detachComps.len == 0 or fromArch.containsAllOf(detachComps):
                let toArch = fromArch.removeAndAdd(toRemove, attachComps)
                if fromArch == toArch:
                    if attachComps.len > 0:
                        cases.add(nnkOfBranch.newTree(ofBranch, details.createArchUpdate(title, attachComps, toArch)))
                    else:
                        needsElse = true
                elif toArch in details.archetypes:
                    let convert = newConverter(fromArch, attachComps, toArch, true)
                    result.convertProcs.add(convert.buildConverter)
                    cases.add(
                        nnkOfBranch.newTree(ofBranch,
                        details.createArchMove(title, fromArch, attachComps, toArch, convert)))
                else:
                    needsElse = true
            else:
                needsElse = true
        if needsElse:
            cases.add(nnkElse.newTree(nnkDiscardStmt.newTree(newEmptyNode())))

    result.procBody = quote do:
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
        let (body, convertProcs) = details.attachDetachProcBody("Attaching", attach.comps, @[], @[])

        let appStateTypeName = details.appStateTypeName
        return quote do:
            `convertProcs`
            proc `attachProc`(
                `appStateIdent`: var `appStateTypeName`,
                `entityId`: EntityId,
                `newComps`: sink `componentTuple`
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

proc splitDetachArgs(args: openarray[DirectiveArg]): tuple[detach: seq[ComponentDef], optDetach: seq[ComponentDef]] =
    for arg in args:
        if arg.kind == Optional:
            result.optDetach.add(arg.component)
        else:
            result.detach.add(arg.component)

proc detachArchetype(builder: var ArchetypeBuilder[ComponentDef], systemArgs: seq[SystemArg], dir: TupleDirective) =
    let partition = dir.args.splitDetachArgs
    builder.detachable(partition.detach, partition.optDetach)

proc detachFields(name: string, dir: TupleDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("Detach"), dir.asTupleType)) ]

proc generateDetach(details: GenerateContext, arg: SystemArg, name: string, detach: TupleDirective): NimNode =
    ## Generates the code for instantiating queries

    let detachProc = details.globalName(name)

    case details.hook
    of GenerateHook.Outside:
        let appStateTypeName = details.appStateTypeName
        let (detachComps, optDetachComps) = detach.args.splitDetachArgs
        let (body, convertProcs) = details.attachDetachProcBody("Detaching", @[], detachComps, optDetachComps)
        return quote:
            `convertProcs`
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
        let (detachComps, optDetachComps) = dir.second.splitDetachArgs
        let (body, convertProcs) = details.attachDetachProcBody("Swapping", dir.first.comps, detachComps, optDetachComps)
        let appStateTypeName = details.appStateTypeName
        return quote do:
            `convertProcs`
            proc `swapProc`(
                `appStateIdent`: var `appStateTypeName`,
                `entityId`: EntityId,
                `newComps`: sink `componentTuple`
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
    let attach = dir.first.comps
    let (detach, optDetach) = dir.second.splitDetachArgs
    for arg in systemArgs.allArgs:
        if arg.generator.isAttachable:
            builder.attachDetach(attach, detach, optDetach, arg.tupleDir.filter)

proc swapFields(name: string, dir: DualDirective): seq[WorldField] =
    @[ (name, nnkBracketExpr.newTree(bindSym("Swap"), dir.first.asTupleType, dir.second.asTupleType)) ]

let swapGenerator* {.compileTime.} = newGenerator(
    ident = "Swap",
    interest = { Outside, Standard },
    generate = generateSwap,
    archetype = swapArchetype,
    worldFields = swapFields,
)
