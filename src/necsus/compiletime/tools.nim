import tables, macros, sequtils, options
import tupleDirective, componentDef
import ../runtime/query

proc copyTuple*[T](
    fromVar: NimNode,
    fromTuple: openarray[T],
    toTuple: openarray[tuple[entry: T, isPointer: bool]]
): NimNode =
    ## Generates code for copying from one tuple to another
    var indexes = initTable[T, int](fromTuple.len)
    for i, fromValue in fromTuple: indexes[fromValue] = i

    result = nnkTupleConstr.newTree()
    for (toEntry, isPointer) in toTuple:
        let readExpr = nnkBracketExpr.newTree(fromVar, newLit(indexes[toEntry]))
        if isPointer:
            result.add(nnkAddr.newTree(readExpr))
        else:
            result.add(readExpr)

proc copyTuple*[T](fromVar: NimNode, fromTuple: openarray[T], toTuple: openarray[T]): NimNode =
    ## Generates code for copying from one tuple to another
    fromVar.copyTuple(fromTuple, toTuple.toSeq.mapIt((it, false)))

proc copyTuple*(fromVar: NimNode, fromTuple: openarray[ComponentDef], toTuple: openarray[DirectiveArg]): NimNode =
    ## Generates code for copying from one tuple to another
    fromVar.copyTuple(fromTuple, toTuple.toSeq.mapIt((it.component, it.isPointer)))

proc asTupleType*(args: openarray[DirectiveArg]): NimNode =
    ## Creates a tuple type from a list of components
    result = nnkTupleConstr.newTree()
    for arg in args:
        let componentIdent = if arg.isPointer: nnkPtrTy.newTree(arg.component.ident) else: arg.component.ident
        case arg.kind
        of Include: result.add(componentIdent)
        of Exclude: result.add(nnkBracketExpr.newTree(bindSym("Not"), componentIdent))
        of Optional: result.add(nnkBracketExpr.newTree(bindSym("Option"), componentIdent))
