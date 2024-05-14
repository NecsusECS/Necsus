import macros, options, sequtils
import tupleDirective, componentDef, archetype, worldEnum, systemGen, directiveArg, commonVars
import ../runtime/query

proc read(fromVar: NimNode, fromArch: Archetype[ComponentDef], arg: DirectiveArg): NimNode =
    let readExpr = nnkBracketExpr.newTree(fromVar, newLit(fromArch.indexOf(arg.component)))
    return if arg.isPointer: nnkAddr.newTree(readExpr) else: readExpr

proc copyTuple*(fromVar: NimNode, fromArch: Archetype[ComponentDef], directive: TupleDirective): NimNode =
    ## Generates code for copying from one tuple to another
    result = nnkTupleConstr.newTree()

    for arg in directive.args:
        case arg.kind
        of DirectiveArgKind.Exclude:
            result.add(newCall(nnkBracketExpr.newTree(bindSym("Not"), arg.type), newLit(0'i8)))
        of DirectiveArgKind.Include:
            result.add(fromVar.read(fromArch, arg))
        of DirectiveArgKind.Optional:
            if arg.component in fromArch:
                result.add(newCall(bindSym("some"), fromVar.read(fromArch, arg)))
            else:
                result.add(newCall(nnkBracketExpr.newTree(bindSym("none"), arg.type)))

proc asTupleType*(components: openarray[ComponentDef]): NimNode =
    ## Creates a tuple type from a list of components
    result = nnkTupleConstr.newTree()
    for comp in components:
        result.add(comp.node)

proc asTupleType*(args: openarray[DirectiveArg]): NimNode =
    ## Creates a tuple type from a list of components
    result = nnkTupleConstr.newTree()
    for arg in args:
        let componentIdent = if arg.isPointer: nnkPtrTy.newTree(arg.component.ident) else: arg.component.ident
        case arg.kind
        of Include: result.add(componentIdent)
        of Exclude: result.add(nnkBracketExpr.newTree(bindSym("Not"), componentIdent))
        of Optional: result.add(nnkBracketExpr.newTree(bindSym("Option"), componentIdent))

proc asTupleType*(tupleDir: TupleDirective): NimNode = tupleDir.args.toSeq.asTupleType

iterator archetypeCases*(details: GenerateContext): tuple[ofBranch: NimNode, archetype: Archetype[ComponentDef]] =
    for archetype in details.archetypes:
        yield (details.archetypeEnum.ident(archetype), archetype)

proc joinStrs*(args: varargs[NimNode]): NimNode =
    ## Joins a set of stringable nim nodes into a string
    if args.len == 0:
        result = newLit("")
    else:
        result = newEmptyNode()
        for arg in args:
            let argStr = nnkPrefix.newTree(ident("$"), arg)
            if result.kind == nnkEmpty:
                result = argStr
            else:
                result = nnkInfix.newTree(ident("&"), result, argStr)

proc loggable*(node: NimNode): NimNode = node

proc loggable*(str: string): NimNode = newLit(str)

proc emitEntityTrace*(args: varargs[NimNode, loggable]): NimNode =
    ## Emits function call for logging an execution event
    if defined(necsusEntityTrace):
        let msg = args.joinStrs
        return quote:
            `appStateIdent`.config.log(`msg`)
    else:
        return newEmptyNode()