import macros, monoDirective, systemGen, std/[importutils, options], common, ../util/typeReader

proc worldFields(name: string, dir: MonoDirective): seq[WorldField] = @[ (name, dir.argType) ]

proc generate(details: GenerateContext, arg: SystemArg, name: string, dir: MonoDirective): NimNode =
    result = newStmtList()
    let nameIdent = ident(name)

    case details.hook
    of Late:
        let bundleType = dir.argType
        let construct = nnkObjConstr.newTree(bundleType)

        for nested in arg.nestedArgs:
            construct.add(nnkExprColonExpr.newTree(ident(nested.originalName), details.systemArg(nested)))

        result.add quote do:
            privateAccess(`bundleType`)
            `appStateIdent`.`nameIdent` = `construct`
    else:
        discard

proc systemArg(name: string, dir: MonoDirective): NimNode =
    let nameIdent = name.ident
    return quote:
        addr `appStateIdent`.`nameIdent`

proc nestedArgs(dir: MonoDirective): seq[RawNestedArg] =
    ## Looks up all the fields on the bundled object and returns them as nested fields

    let bundleImpl = dir.argType.resolveTo({nnkObjectTy})

    let impl: NimNode = if bundleImpl.isSome:
        bundleImpl.get
    else:
        dir.argType.expectKind(nnkObjectTy)
        newEmptyNode()

    impl[2].expectKind({ nnkRecList, nnkEmpty })

    for child in impl[2].children:
        child.expectKind(nnkIdentDefs)

        let name = if child[0].kind == nnkPostfix: child[0][1] else: child[0]
        name.expectKind(nnkIdent)
        result.add((name, child[1]))

let bundleGenerator* {.compileTime.} = newGenerator(
    ident = "Bundle",
    interest = { Late },
    generate = generate,
    worldFields = worldFields,
    systemArg = systemArg,
    nestedArgs = nestedArgs
)

