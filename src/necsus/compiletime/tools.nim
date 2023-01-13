import tables, macros, options
import tupleDirective, componentDef, codeGenInfo, archetype, worldEnum
import ../runtime/query

proc copyTuple*(fromVar: NimNode, fromArch: Archetype[ComponentDef], directive: TupleDirective): NimNode =
    ## Generates code for copying from one tuple to another
    result = nnkTupleConstr.newTree()

    proc read(arg: DirectiveArg): auto =
        let readExpr = nnkBracketExpr.newTree(fromVar, newLit(fromArch.indexOf(arg.component)))
        return if arg.isPointer: nnkAddr.newTree(readExpr) else: readExpr

    for arg in directive.args:
        case arg.kind
        of DirectiveArgKind.Exclude:
            result.add(newLit(0))
        of DirectiveArgKind.Include:
            result.add(arg.read)
        of DirectiveArgKind.Optional:
            if arg.component in fromArch:
                result.add(newCall(bindSym("some"), arg.read))
            else:
                result.add(newCall(bindSym("none"), arg.type))

proc asTupleType*(args: openarray[DirectiveArg]): NimNode =
    ## Creates a tuple type from a list of components
    result = nnkTupleConstr.newTree()
    for arg in args:
        let componentIdent = if arg.isPointer: nnkPtrTy.newTree(arg.component.ident) else: arg.component.ident
        case arg.kind
        of Include: result.add(componentIdent)
        of Exclude: result.add(nnkBracketExpr.newTree(bindSym("Not"), componentIdent))
        of Optional: result.add(nnkBracketExpr.newTree(bindSym("Option"), componentIdent))

proc createArchetypeCase*(
    genInfo: CodeGenInfo,
    readArchetype: NimNode,
    branch: proc (arch: Archetype[ComponentDef]): NimNode
): NimNode =
    ## Creates a case statement for all possible archetypes
    result = nnkCaseStmt.newTree(readArchetype)
    for archetype in genInfo.archetypes:
        result.add(nnkOfBranch.newTree(genInfo.archetypeEnum.enumRef(archetype), branch(archetype)))
