import std/[macros], ../util/[typeReader]

macro extend*(a, b: typedesc): typedesc =
  ## Combines tuples type definitions to create a new tuple type
  result = nnkTupleConstr.newTree()
  result.copyLineInfo(a)

  for typ in a.getTupleSubtypes():
    result.add(typ)
  for typ in b.getTupleSubtypes():
    result.add(typ)

proc `as`*[T: tuple](value: T, typ: typedesc): T =
  ## Casts a value to a type and returns it. Used for joining tuples
  static:
    assert(typ is T)
  value

proc getTupleData(tup: NimNode): tuple[typ: NimNode, construct: NimNode] =
  case tup.kind
  of nnkInfix:
    if tup[0].strVal != "as":
      error("Expecting an 'as' infix operator", tup[0])
    return (typ: tup[2], construct: tup[1])
  of nnkTupleConstr:
    return (typ: tup.getTypeInst, construct: tup)
  else:
    tup.expectKind({nnkInfix, nnkTupleConstr})

macro join*(exprs: varargs[typed]): untyped =
  ## Combines two tuple values into a single tuple value according to the sorting
  ## rules for archetype component types

  exprs.expectKind(nnkBracket)

  var lets = nnkLetSection.newTree()
  var children: seq[(NimNode, int, NimNode)]

  for tup in exprs:
    let (tupleType, tupleConstruct) = tup.getTupleData()

    let thisVar = genSym(nskLet, "temp")
    lets.add(nnkIdentDefs.newTree(thisVar, tupleType, tupleConstruct))

    let tupleSubs = tupleType.getTupleSubtypes()
    for i, child in tupleSubs:
      children.add((thisVar, i, child))

  var output = nnkTupleConstr.newTree()
  for (source, idx, _) in children:
    output.add(nnkBracketExpr.newTree(source, newLit(idx)))

  return newStmtList(lets, output)
