import codeGenInfo, localDef, macros, directiveSet
import ../runtime/systemVar

proc defineVars[T](directives: DirectiveSet[T], construct: NimNode): NimNode =
    result = newStmtList()
    for (name, directive) in directives:
        let varIdent = ident(name)
        let argType = directive.argType
        result.add quote do:
            var `varIdent` = `construct`[`argType`]()

proc createLocalVars*(codeGenInfo: CodeGenInfo): NimNode =
    ## Generates the code necessary for storing local variables
    defineVars(codeGenInfo.locals, bindSym("newLocal"))

proc createSharedVars*(codeGenInfo: CodeGenInfo): NimNode =
    ## Generates the code necessary for storing local variables
    result = newStmtList(defineVars(codeGenInfo.shared, bindSym("newShared")))

    for (argName, shared) in codeGenInfo.app.inputs:
        let argIdent = ident(argName)
        let sharedVarIdent = codeGenInfo.shared.nameOf(shared).ident
        result.add quote do: `sharedVarIdent`.set(`argIdent`)
