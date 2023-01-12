import macros, sequtils
import tools, codeGenInfo, directiveSet, tupleDirective, commonVars, archetype, componentDef, worldEnum
import ../runtime/world

let entityIndex {.compileTime.} = ident("entityIndex")
let newComps {.compileTime.} = ident("comps")

proc createArchUpdate(attach: AttachDef, archetype: Archetype[ComponentDef]): NimNode =
    ## Creates code for updating archetype information in place
    result = newStmtList()

    let archIdent = archetype.ident
    let archTuple = archetype.asStorageTuple

    let existing = ident("existing")

    result.add quote do:
        let `existing` = getComps[`archTuple`](`archIdent`, `entityIndex`.archetypeIndex)

    for i, component in attach.items.toSeq:
        let storageIndex = archetype.indexOf(component)
        result.add quote do:
            `existing`[`storageIndex`] = `newComps`[`i`]

proc createArchCopy(attach: AttachDef, fromArch: Archetype[ComponentDef], toArch: Archetype[ComponentDef]): NimNode =
    nnkDiscardStmt.newTree(newEmptyNode())

proc createArchetypeBranch(genInfo: CodeGenInfo, attach: AttachDef, fromArch: Archetype[ComponentDef]): NimNode =
    ## Creates code for for copying from one archetype to another
    let toArch = fromArch + attach.items.toSeq

    let work = if fromArch == toArch:
        createArchUpdate(attach, toArch)
    else:
        createArchCopy(attach, fromArch, toArch)

    return nnkOfBranch.newTree(genInfo.archetypeEnum.enumRef(fromArch), work)

proc createAttachProc(genInfo: CodeGenInfo, name: string, attach: AttachDef): NimNode =
    ## Generates a proc to update components for an entity
    let procName = ident(name)
    let entityId = ident("entityId")
    let componentTuple = attach.args.toSeq.asTupleType

    let cases = nnkCaseStmt.newTree(newDotExpr(entityIndex, ident("archetype")))
    for archetype in genInfo.archetypes:
        cases.add(genInfo.createArchetypeBranch(attach, archetype))

    result = quote:
        proc `procName`(`entityId`: EntityId, `newComps`: `componentTuple`) {.used.} =
            let `entityIndex` = `worldIdent`[`entityId`]
            `cases`

proc createAttachProcs*(genInfo: CodeGenInfo): NimNode =
    ## Creates the procs necessary to attach new components to an entity
    result = newStmtList()
    for (name, attach) in genInfo.attaches:
        result.add(genInfo.createAttachProc(name, attach))
