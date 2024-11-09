import macros, options, tables

proc isPragma*(found, expect: NimNode): bool =
    ## Determines whether a NimNode represents the given pragma
    expect.expectKind({ nnkSym })
    case found.kind
    of nnkSym: return found == expect
    of nnkCall: return found[0].isPragma(expect)
    of nnkIdent: return false
    of nnkExprColonExpr: return found[0].isPragma(expect)
    else: error("Unable to extract pragma from " & found.lispRepr, found)

proc findPragma*(node: NimNode): NimNode =
    ## Finds the pragma node attached to a nim node
    case node.kind
    of nnkSym:
        if node.symKind == nskType:
            return node.getImpl.findPragma
    of RoutineNodes:
        return node.pragma
    of nnkIdentDefs, nnkTypeDef:
        if node[0].kind == nnkPragmaExpr:
            return node[0][1]
    else:
        discard
    return newEmptyNode()

proc hasPragma*(node, pragma: NimNode): bool =
    ## Determines whether a node has a given pragma
    let pragmaSet = node.findPragma
    if pragmaSet.kind == nnkPragma:
        for child in pragmaSet:
            if child.isPragma(pragma):
                return true

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

proc resolveBracketGeneric*(typeDef: NimNode): NimNode =
    ## Replaces a generic alias with the underlying type it represents
    typeDef.expectKind({ nnkBracketExpr })
    let declaration = typeDef[0].getImpl
    declaration.expectKind(nnkTypeDef)
    let genericTable = declaration[1].asGenericTable(typeDef[1..^1])
    return declaration[2].replaceGenerics(genericTable)

proc resolveTo*(typeDef: NimNode, expectKind: set[NimNodeKind]): Option[NimNode] =
    ## Resolves the system parsable type of an identifier
    if typeDef.kind in expectKind:
        return some(typeDef)

    case typeDef.kind:
    of nnkBracketExpr:
        return typeDef.resolveBracketGeneric().resolveTo(expectKind)
    of nnkSym:
        return typeDef.getImpl.resolveTo(expectKind)
    of nnkTypeDef:
        return typeDef[2].resolveTo(expectKind)
    else:
        return none[NimNode]()

proc resolveAlias*(typeDef: NimNode): Option[NimNode] =
    ## Attempts to resolve any aliases until a concrete type is reached
    case typeDef.kind
    of nnkSym:
        let impl = typeDef.getImpl
        if impl.kind == nnkTypeDef:
            return some(impl[2])
    of nnkBracketExpr:
        return some(typeDef.resolveBracketGeneric())
    else:
        discard

proc findSym*(node: NimNode): NimNode =
    ## Unwraps the symbol from a node
    case node.kind
    of nnkSym: return node
    of nnkIdentDefs, nnkPragmaExpr: return node[0].findSym
    else: error("Could not extract a symbol from " & node.lispRepr, node)