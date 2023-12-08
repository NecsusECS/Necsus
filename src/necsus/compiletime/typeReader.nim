import macros, options, tables, sequtils

proc findPragma*(node: NimNode): NimNode =
    ## Finds the pragma node attached to a nim node
    case node.kind
    of nnkIdentDefs:
        if node[0].kind == nnkPragmaExpr:
            node[0][1]
        else:
            newEmptyNode()
    of nnkSym, nnkConstDef: newEmptyNode()
    else: node.pragma

proc findChildSyms*(node: NimNode, output: var seq[NimNode]) =
    ## Finds all symbols in the children of a node and returns them
    if node.kind == nnkSym:
        output.add(node)
    elif node.kind == nnkEmpty:
        discard
    elif node.len == 0:
        error("Expecting a system symbol, but got: " & node.repr, node)
    else:
        for child in node.children:
            findChildSyms(child, output)

proc asGenericTable(genericParams: NimNode, values: openArray[NimNode]): Table[string, NimNode] =
    ## Creates a table of generic parameters to the actual symbols they represent
    genericParams.expectKind(nnkGenericParams)
    for i, value in values:
        genericParams[i].expectKind(nnkSym)
        result[genericParams[i].strVal] = value

proc replaceGenerics(typeDecl: NimNode, symLookup: Table[string, NimNode]): NimNode =
    ## Copies an AST, but replaces any generic references based on the given lookup table
    if typeDecl.kind in {nnkSym, nnkIdent} and typeDecl.strVal in symLookup:
        return symLookup[typeDecl.strVal]
    elif typeDecl.len == 0:
        return typeDecl
    result = newNimNode(typeDecl.kind)
    for child in typeDecl.children:
        result.add(child.replaceGenerics(symLookup))

proc resolveTo*(typeDef: NimNode, expectKind: set[NimNodeKind]): Option[NimNode] =
    ## Resolves the system parsable type of an identifier
    if typeDef.kind in expectKind:
        return some(typeDef)

    case typeDef.kind:
    of nnkBracketExpr:
        let declaration = typeDef[0].getImpl
        declaration.expectKind(nnkTypeDef)
        let genericTable = declaration[1].asGenericTable(typeDef.children.toSeq[1..^1])
        return declaration[2].replaceGenerics(genericTable).resolveTo(expectKind)
    of nnkSym:
        return typeDef.getImpl.resolveTo(expectKind)
    of nnkTypeDef:
        return typeDef[2].resolveTo(expectKind)
    else:
        return none[NimNode]()