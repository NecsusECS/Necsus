import codeGenInfo, macros, directiveSet, tupleDirective, sequtils, queryGen

proc createQueryRemovals(codeGenInfo: CodeGenInfo, entityId: NimNode, queries: openarray[QueryDef]): NimNode =
    # Generate code for detaching this entity from any associated queries
    result = newStmtList()
    for query in queries:
        let queryIdent = codeGenInfo.queries.nameOf(query).queryStorageIdent
        result.add quote do:
            removeFromQuery(`queryIdent`, `entityId`)

proc createDetach*(codeGenInfo: CodeGenInfo, name: string, detach: DetachDef): NimNode =
    ## Creates a proc for detaching components
    let procName = ident(name)
    let entityId = ident("entityId")
    let componentEnum = codeGenInfo.createComponentEnum(detach.toSeq)
    let queryRemovals = codeGenInfo.createQueryRemovals(entityId, codeGenInfo.queries.mentioning(detach.toSeq))

    result = quote:
        proc `procName`(`entityId`: EntityId) =
            detachComponents(`worldIdent`, `entityId`, `componentEnum`)
            `queryRemovals`

proc createDetaches*(codeGenInfo: CodeGenInfo): NimNode =
    ## Generates procs for detaching components from entities
    result = newStmtList()
    for (name, detach) in codeGenInfo.detaches:
        result.add(codeGenInfo.createDetach(name, detach))

proc createDeleteProc*(codeGenInfo: CodeGenInfo): NimNode =
    ## Generates all the procs for updating entities
    let entity = ident("entity")
    let queryRemovals = codeGenInfo.createQueryRemovals(entity, codeGenInfo.queries.directives)
    result = quote do:
        proc `deleteProc`(`entity`: EntityId) =
            `worldIdent`.deleteEntity(`entity`)
            `queryRemovals`
