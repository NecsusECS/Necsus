import std/[options, macros, algorithm, sequtils], ../util/[typeReader, nimNode]

proc getTupleSubtypes(typ: NimNode): seq[NimNode] =
    let resolved = typ.resolveTo({nnkTupleConstr, nnkTupleTy, nnkCall}).get(typ)
    case resolved.kind
    of nnkTupleConstr:
        result = resolved.children.toSeq
    of nnkTupleTy:
        for child in resolved:
            child.expectKind(nnkIdentDefs)
            result.add(child[1])
    of nnkCall:
        if resolved[0].strval == "extend":
            result = resolved[1].getTupleSubtypes() & resolved[2].getTupleSubtypes()
        else:
            error("Unable to resolve tuple type for " & resolved.repr, resolved)
    else:
        resolved.expectKind({nnkTupleConstr, nnkTupleTy, nnkSym})

macro extend*(a, b: typedesc): typedesc =
    ## Combines two tuples to create a new tuple
    let tupleA = a.getTupleSubtypes()
    let tupleB = b.getTupleSubtypes()

    var children = concat(tupleA, tupleB)
    children.sort(nimNode.cmp)

    result = nnkTupleConstr.newTree(children)
    result.copyLineInfo(a)

macro join*(aType, bType: typedesc, a, b: typed): untyped =
    ## Combines two tuple values into a single tuple value according to the sorting
    ## rules or archetype component types
    let tupleA = aType.getTupleSubtypes()
    let tupleB = bType.getTupleSubtypes()

    var children: seq[(bool, int, NimNode)]
    for i, child in tupleA: children.add((true, i, child))
    for i, child in tupleB: children.add((false, i, child))
    children.sort do (a, b: (bool, int, NimNode)) -> int:
        return nimNode.cmp(a[2], b[2])

    let aVar = genSym(nskLet, "tupleA")
    let bVar = genSym(nskLet, "tupleB")
    var output = nnkTupleConstr.newTree()

    result = newStmtList(
        nnkLetSection.newTree(
            nnkIdentDefs.newTree(aVar, aType, a),
            nnkIdentDefs.newTree(bVar, bType, b),
        ),
        output
    )

    for (aOrB, idx, _) in children:
        let source = if aOrB: aVar else: bVar
        output.add(nnkBracketExpr.newTree(source, newLit(idx)))