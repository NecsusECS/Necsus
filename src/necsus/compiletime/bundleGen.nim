import macros, monoDirective, systemGen

proc worldFields(name: string, dir: MonoDirective): seq[WorldField] = @[]

proc generateShared(details: GenerateContext, arg: SystemArg, name: string, dir: MonoDirective): NimNode =
    result = newStmtList()
    let nameIdent = ident(name)

    case details.hook
    of LoopStart, Late, BeforeTeardown:
        let construct = nnkObjConstr.newTree(dir.argType)

        for nested in arg.nestedArgs:
            construct.add(nnkExprColonExpr.newTree(ident(nested.originalName), details.systemArg(nested)))

        result.add quote do:
            var `nameIdent` {.used.} = `construct`
    else:
        discard

proc systemArg(name: string, dir: MonoDirective): NimNode =
    let nameIdent = name.ident
    return quote:
        addr `nameIdent`

proc nestedArgs(dir: MonoDirective): seq[RawNestedArg] =
    ## Looks up all the fields on the bundled object and returns them as nested fields
    let impl = dir.argType.getImpl
    impl.expectKind(nnkTypeDef)
    impl[2].expectKind(nnkObjectTy)
    impl[2][2].expectKind(nnkRecList)

    for child in impl[2][2].children:
        child.expectKind(nnkIdentDefs)

        let name = child[0]
        if name.kind != nnkPostfix or name[0].kind != nnkIdent or name[0].strVal != "*":
            error("Expecting field to be public", child)

        name[1].expectKind(nnkIdent)
        result.add((name[1].strVal, child[1]))

let bundleGenerator* {.compileTime.} = newGenerator(
    ident = "Bundle",
    generate = generateShared,
    worldFields = worldFields,
    systemArg = systemArg,
    nestedArgs = nestedArgs
)

