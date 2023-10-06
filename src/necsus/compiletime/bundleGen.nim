import macros, monoDirective, systemGen, std/importutils

proc worldFields(name: string, dir: MonoDirective): seq[WorldField] = @[]

proc generateShared(details: GenerateContext, arg: SystemArg, name: string, dir: MonoDirective): NimNode =
    result = newStmtList()
    let nameIdent = ident(name)

    case details.hook
    of LoopStart, Late, BeforeTeardown:
        let bundleType = dir.argType
        let construct = nnkObjConstr.newTree(bundleType)

        for nested in arg.nestedArgs:
            construct.add(nnkExprColonExpr.newTree(ident(nested.originalName), details.systemArg(nested)))

        result.add quote do:
            privateAccess(`bundleType`)
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

        let name = if child[0].kind == nnkPostfix: child[0][1] else: child[0]
        name.expectKind(nnkIdent)
        result.add((name.strVal, child[1]))

let bundleGenerator* {.compileTime.} = newGenerator(
    ident = "Bundle",
    generate = generateShared,
    worldFields = worldFields,
    systemArg = systemArg,
    nestedArgs = nestedArgs
)

