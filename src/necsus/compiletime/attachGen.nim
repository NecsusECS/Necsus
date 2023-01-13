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
    let archetypeEnum = genInfo.archetypeEnum.enumSymbol

    let existing = ident("existing")
    result.add quote do:
        let `existing` = getComps[`archetypeEnum`, `archTuple`](`archIdent`, `entityIndex`.archetypeIndex)

    for i, component in attach.items.toSeq:
        let storageIndex = archetype.indexOf(component)
        result.add quote do:
            `existing`[`storageIndex`] = `newComps`[`i`]

proc createArchMove(
    genInfo: CodeGenInfo,
    attach: AttachDef,
    fromArch: Archetype[ComponentDef],
    toArch: Archetype[ComponentDef]
): NimNode =
    ## Creates code for copying from one archetype to another
    let fromArchIdent = fromArch.ident
    let fromArchTuple = fromArch.asStorageTuple
    let toArchTuple = toArch.asStorageTuple
    let toArchIdent = toArch.ident
    let archetypeEnum = genInfo.archetypeEnum.enumSymbol
    let existing = ident("existing")

    let createNewTuple = nnkTupleConstr.newTree()
    for comp in toArch.items:
        if comp in attach:
            createNewTuple.add(nnkBracketExpr.newTree(newComps, newLit(attach.indexOf(comp))))
        else:
            createNewTuple.add(nnkBracketExpr.newTree(existing, newLit(fromArch.indexOf(comp))))

    return quote:
        moveEntity[`archetypeEnum`, `fromArchTuple`, `toArchTuple`](
            `worldIdent`, `entityIndex`, `fromArchIdent`, `toArchIdent`,
            proc (`existing`: ptr `fromArchTuple`): auto = `createNewTuple`
        )

proc createArchetypeBranch(genInfo: CodeGenInfo, attach: AttachDef, fromArch: Archetype[ComponentDef]): NimNode =
    ## Creates code for for copying from one archetype to another
    let toArch = genInfo.archetypes[concat(fromArch.items.toSeq, attach.items.toSeq)]

    let work = if fromArch == toArch:
        createArchUpdate(genInfo, attach, toArch)
    else:
        genInfo.createArchMove(attach, fromArch, toArch)

    return nnkOfBranch.newTree(genInfo.archetypeEnum.enumRef(fromArch), work)

proc createAttachProc(genInfo: CodeGenInfo, name: string, attach: AttachDef): NimNode =
    ## Generates a proc to update components for an entity
    let procName = ident(name)
    let componentTuple = attach.args.toSeq.asTupleType

    let cases = nnkCaseStmt.newTree(newDotExpr(entityIndex, ident("archetype")))
    for archetype in genInfo.archetypes:
        cases.add(genInfo.createArchetypeBranch(attach, archetype))

    result = quote:
        proc `procName`(`entityId`: EntityId, `newComps`: `componentTuple`) {.used.} =
            var `entityIndex` = `worldIdent`[`entityId`]
            `cases`

proc createAttachProcs*(genInfo: CodeGenInfo): NimNode =
    ## Creates the procs necessary to attach new components to an entity
    result = newStmtList()
    for (name, attach) in genInfo.attaches:
        result.add(genInfo.createAttachProc(name, attach))
