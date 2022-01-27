import codeGenInfo, localDef, macros, directiveSet

proc createLocalVars*(codeGenInfo: CodeGenInfo): NimNode =
    ## Generates the code necessary for storing local variables
    result = newStmtList()
    for (name, local) in codeGenInfo.locals:
        let varIdent = ident(name)
        let argType = local.argType
        result.add quote do:
            var `varIdent` = newLocal[`argType`]()
