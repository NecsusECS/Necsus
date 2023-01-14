import macros, sequtils
import tools, codeGenInfo, directiveSet, tupleDirective, commonVars, archetype, componentDef, worldEnum
import ../runtime/[world, archetypeStore]

let entityIndex {.compileTime.} = ident("entityIndex")
let newComps {.compileTime.} = ident("comps")
let entityId {.compileTime.} = ident("entityId")

proc createArchUpdate(genInfo: CodeGenInfo, attach: AttachDef, archetype: Archetype[ComponentDef]): NimNode =
    ## Creates code for updating archetype information in place
    result = newStmtList()

    let archIdent = archetype.ident
    let archTuple = archetype.asStorageTuple
    let archetypeEnum = genInfo.archetypeEnum.ident

    let existing = ident("existing")
    result.add quote do:
        let `existing` = getComps[`archetypeEnum`, `archTuple`](`archIdent`, `entityIndex`.archetypeIndex)

    for i, component in attach.items.toSeq:
        let storageIndex = archetype.indexOf(component)
        result.add quote do:
            `existing`[`storageIndex`] = `newComps`[`i`]

proc createArchMove(
    genInfo: CodeGenInfo,
    directive: TupleDirective,
    fromArch: Archetype[ComponentDef],
    toArch: Archetype[ComponentDef]
): NimNode =
    ## Creates code for copying from one archetype to another
    let fromArchIdent = fromArch.ident
    let fromArchTuple = fromArch.asStorageTuple
    let toArchTuple = toArch.asStorageTuple
    let toArchIdent = toArch.ident
    let archetypeEnum = genInfo.archetypeEnum.ident
    let existing = ident("existing")

    let createNewTuple = nnkTupleConstr.newTree()
    for comp in toArch.items:
        if comp in directive:
            createNewTuple.add(nnkBracketExpr.newTree(newComps, newLit(directive.indexOf(comp))))
        else:
            createNewTuple.add(nnkBracketExpr.newTree(existing, newLit(fromArch.indexOf(comp))))

    return quote:
        moveEntity[`archetypeEnum`, `fromArchTuple`, `toArchTuple`](
            `worldIdent`, `entityIndex`, `fromArchIdent`, `toArchIdent`,
            proc (`existing`: ptr `fromArchTuple`): auto = `createNewTuple`
        )

proc createAttachProc(genInfo: CodeGenInfo, name: string, attach: AttachDef): NimNode =
    ## Generates a proc to update components for an entity
    let procName = ident(name)
    let componentTuple = attach.args.toSeq.asTupleType

    ## Generate a cases statement to do the work for each kind of archetype
    let cases = genInfo.createArchetypeCase(newDotExpr(entityIndex, ident("archetype"))) do (fromArch: auto) -> auto:
        let toArch = genInfo.archetypes[concat(fromArch.values, attach.comps)]
        return if fromArch == toArch:
            genInfo.createArchUpdate(attach, toArch)
        else:
            genInfo.createArchMove(attach, fromArch, toArch)

    result = quote:
        proc `procName`(`entityId`: EntityId, `newComps`: `componentTuple`) {.used.} =
            var `entityIndex` = `worldIdent`[`entityId`]
            `cases`

proc createAttachProcs*(genInfo: CodeGenInfo): NimNode =
    ## Creates the procs necessary to attach new components to an entity
    result = newStmtList()
    for (name, attach) in genInfo.attaches:
        result.add(genInfo.createAttachProc(name, attach))

proc createDetachProc*(genInfo: CodeGenInfo, name: string, detach: DetachDef): NimNode =
    ## Creates a proc for detaching components
    let procName = ident(name)

    let cases = genInfo.createArchetypeCase(newDotExpr(entityIndex, ident("archetype"))) do (fromArch: auto) -> auto:
        if fromArch.containsAllOf(detach.comps):
            # echo fromArch, " - ", detach.comps, " = ", fromArch.values.filterIt(it notin detach.comps)
            # return quote: discard
            let toArch = genInfo.archetypes[fromArch.values.filterIt(it notin detach.comps)]
            return genInfo.createArchMove(detach, fromArch, toArch)
        else:
            return quote: discard

    result = quote:
        proc `procName`(`entityId`: EntityId) =
            let `entityIndex` = `worldIdent`[`entityId`]
            `cases`

proc createDetachProcs*(genInfo: CodeGenInfo): NimNode =
    ## Creates the procs necessary to attach new components to an entity
    result = newStmtList()
    for (name, attach) in genInfo.detaches:
        result.add(genInfo.createDetachProc(name, attach))
