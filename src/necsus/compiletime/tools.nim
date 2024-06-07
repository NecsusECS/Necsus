import macros, options, sequtils
import tupleDirective, componentDef, archetype, worldEnum, systemGen, directiveArg, common
import ../runtime/query


proc read(fromVar: NimNode, fromArch: Archetype[ComponentDef], arg: DirectiveArg): NimNode =
    let readExpr = nnkBracketExpr.newTree(fromVar, newLit(fromArch.indexOf(arg.component)))
    return if arg.isPointer: nnkAddr.newTree(readExpr) else: readExpr

proc copyTuple*(fromVar, toVar: NimNode, fromArch: Archetype[ComponentDef], directive: TupleDirective): NimNode =
    ## Generates code for copying from one tuple to another
    result = newStmtList()

    for i, arg in directive.args:
        let value = case arg.kind
            of DirectiveArgKind.Exclude:
                newCall(nnkBracketExpr.newTree(bindSym("Not"), arg.type), newLit(0'i8))
            of DirectiveArgKind.Include:
                fromVar.read(fromArch, arg)
            of DirectiveArgKind.Optional:
                if arg.component in fromArch:
                    newCall(bindSym("some"), fromVar.read(fromArch, arg))
                else:
                    newCall(nnkBracketExpr.newTree(bindSym("none"), arg.type))
        result.add quote do:
            `toVar`[`i`] = `value`

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

proc emitLog*(args: varargs[NimNode, loggable]): NimNode =
    ## Generates code to emit a log message
    let msg = args.joinStrs
    return quote:
        `appStateIdent`.config.log(`msg`)

proc emitEntityTrace*(args: varargs[NimNode, loggable]): NimNode =
    ## Emits function call for logging an entity related event
    return if defined(necsusEntityTrace): emitLog(args) else: return newEmptyNode()

proc emitEventTrace*(args: varargs[NimNode, loggable]): NimNode =
    ## Emits code needed to generate an event tracing log
    return if defined(necsusEventTrace): emitLog(args) else: return newEmptyNode()

proc emitQueryTrace*(args: varargs[NimNode, loggable]): NimNode =
    ## Emits code needed to generate query tracing logs
    return if defined(necsusQueryTrace): emitLog(args) else: return newEmptyNode()

proc emitSaveTrace*(args: varargs[NimNode, loggable]): NimNode =
    ## Emits code needed to generate save tracing logs
    return if defined(necsusSaveTrace): emitLog(args) else: return newEmptyNode()