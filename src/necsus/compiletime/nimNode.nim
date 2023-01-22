import macros, strformat, strutils, sequtils, hashes

proc symbols*(node: NimNode): seq[string] =
    ## Extracts all the symbols from a NimNode tree
    case node.kind
    of nnkSym, nnkIdent, nnkStrLit..nnkTripleStrLit: return @[node.strVal.toLowerAscii]
    of nnkCharLit..nnkUInt64Lit: return @[$node.intVal]
    of nnkFloatLit..nnkFloat64Lit: return @[$node.floatVal]
    of nnkNilLit: return @["nil"]
    of nnkBracketExpr: return node.toSeq.mapIt(it.symbols).foldl(concat(a, b))
    else: error(&"Unable to generate a component symbol from node ({node.kind}): {node.repr}")

proc hash*(node: NimNode): Hash =
    ## Generates a unique hash for a NimNode
    case node.kind:
    of nnkSym, nnkIdent, nnkStrLit..nnkTripleStrLit: return hash(node.strVal)
    of nnkCharLit..nnkUInt64Lit: return hash(node.intVal)
    of nnkFloatLit..nnkFloat64Lit: return hash(node.floatVal)
    of nnkNilLit: return hash(0)
    of nnkBracketExpr: return node.toSeq.mapIt(hash(it)).foldl(a !& b, hash(node.kind))
    else: error(&"Unable to generate a hash from node ({node.kind}): {node.repr}")

proc cmp*(a: NimNode, b: NimNode): int =
    ## Compare two nim nodes for sorting
    if a.kind == nnkSym and b.kind == nnkSym:
        return cmp(a.signatureHash, b.signatureHash)
    if a.kind in {nnkSym, nnkIdent} and b.kind in {nnkSym, nnkIdent}:
        return cmp(a.strVal, b.strVal)
    if a.kind != b.kind:
        return cmp(a.kind, b.kind)
    elif a.len != b.len:
        return cmp(a.len, b.len)
    else:
        for i in 0..<a.len:
            let compared = cmp(a[i], b[i])
            if compared != 0:
                return compared
        return 0