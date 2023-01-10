import entityId, macros

type
    SpawnFill*[C: tuple] = proc (entityId: EntityId, components: var C)
        ## A callback for populating a component with values

    Spawn*[C: tuple] = proc(populate: SpawnFill[C]): EntityId
        ## Describes a type that is able to create new entities. Where `C` is a tuple
        ## with all the components to initially attach to this entity

macro buildAssignment(componentType: untyped, values: varargs[untyped]): untyped =
    let slotIdent = ident("slot")
    var assignments = newStmtList()
    for i, elem in values:
        assignments.add(newAssignment(nnkBracketExpr.newTree(slotIdent, newLit(i)), elem))

    result = newProc(
        procType = nnkLambda,
        params = [
            "void".ident,
            newIdentDefs("entityId".ident, bindSym("EntityId")),
            newIdentDefs("slot".ident, nnkVarTy.newTree(componentType))
        ],
        body = assignments
    )


template with*[C: tuple](spawn: Spawn[C], values: varargs[untyped]): EntityId =
    ## spawns the given values
    spawn(buildAssignment(C, values))
