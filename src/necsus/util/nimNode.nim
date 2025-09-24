import macros, strformat, sequtils, hashes

proc symbols*(node: NimNode): seq[string] =
  ## Extracts all the symbols from a NimNode tree
  case node.kind
  of nnkSym, nnkIdent, nnkStrLit .. nnkTripleStrLit:
    return @[node.strVal]
  of nnkCharLit .. nnkUInt64Lit:
    return @[$node.intVal]
  of nnkFloatLit .. nnkFloat64Lit:
    return @[$node.floatVal]
  of nnkNilLit:
    return @["nil"]
  of nnkBracketExpr, nnkTupleTy, nnkTupleConstr:
    return node.toSeq.mapIt(it.symbols).foldl(concat(a, b))
  of nnkIdentDefs:
    return concat(node[0].symbols, node[1].symbols)
  of nnkRefTy:
    return concat(@["ref"], node[0].symbols)
  else:
    error(&"Unable to generate a component symbol from node ({node.kind}): {node.repr}", node)

proc hash*(node: NimNode): Hash =
  ## Generates a unique hash for a NimNode
  case node.kind
  of nnkSym, nnkIdent, nnkStrLit .. nnkTripleStrLit:
    return hash(node.strVal)
  of nnkCharLit .. nnkUInt64Lit:
    return hash(node.intVal)
  of nnkFloatLit .. nnkFloat64Lit:
    return hash(node.floatVal)
  of nnkNilLit, nnkEmpty:
    return hash(0)
  of nnkBracketExpr, nnkTupleTy, nnkIdentDefs, nnkTupleConstr:
    return node.toSeq.mapIt(hash(it)).foldl(a !& b, hash(node.kind))
  of nnkRefTy:
    return hash(node[0])
  else:
    error(&"Unable to generate a hash from node ({node.kind}): {node.repr}", node)

proc cmp*(a: NimNode, b: NimNode): int =
  ## Compare two nim nodes for sorting
  if a == b:
    return 0

  if a.kind == nnkSym and b.kind == nnkSym:
    let nameCompare = cmp(a.strVal, b.strVal)
    if nameCompare == 0:
      return cmp(a.signatureHash, b.signatureHash)
    else:
      return nameCompare
  elif a.kind in {nnkSym, nnkIdent} and b.kind in {nnkSym, nnkIdent}:
    return cmp(a.strVal, b.strVal)
  elif a.kind != b.kind:
    return cmp(a.kind, b.kind)
  elif a.len != b.len:
    return cmp(a.len, b.len)
  else:
    for i in 0 ..< a.len:
      let compared = cmp(a[i], b[i])
      if compared != 0:
        return compared
    return 0

proc addSignature*(onto: var string, comp: NimNode) =
  ## Generate a unique ID for a component
  case comp.kind
  of nnkSym:
    onto &= comp.signatureHash
  of nnkBracketExpr, nnkTupleConstr, nnkTupleTy:
    for child in comp.children:
      onto.addSignature(child)
  of nnkIdentDefs:
    onto.addSignature(comp[1])
  else:
    comp.expectKind({nnkSym})
