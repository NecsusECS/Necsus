import macros, sequtils, strformat, options, tables
import componentDef, tupleDirective, monoDirective, systemGen
import ../runtime/pragmas

type
    Parser = object
        ## The pluggable generators
        generators: Table[string, DirectiveGen]

    SystemPhase* = enum StartupPhase, LoopPhase, TeardownPhase
        ## When a system should be executed

    ParsedSystem* = object
        ## Parsed information about a system proc
        phase*: SystemPhase
        symbol*: NimNode
        args*: seq[SystemArg]
        depends: seq[NimNode]
        instanced*: Option[NimNode]

    ParsedApp* = object
        ## Parsed information about the application proc itself
        name*: string
        runnerArgs*: seq[SystemArg]
        inputs*: AppInputs
        returns*: Option[MonoDirective]

proc newParser*(generators: varargs[DirectiveGen]): Parser =
    ## Creates a new parser
    result.generators = initTable[string, DirectiveGen]()
    for gen in generators: result.generators[gen.ident] = gen

proc phase*(system: ParsedSystem): auto = system.phase

proc symbol*(system: ParsedSystem): auto = system.symbol

proc kind*(arg: SystemArg): auto = arg.kind

proc parseArgKind(parser: Parser, symbol: NimNode): Option[DirectiveGen] =
    ## Parses a type symbol to a SystemArgKind
    symbol.expectKind(nnkSym)
    if symbol.strVal in parser.generators:
        return some(parser.generators[symbol.strVal])
    else:
        return none(DirectiveGen)

proc parseDirectiveArg(symbol: NimNode, isPointer: bool = false, kind: DirectiveArgKind = Include): DirectiveArg =
    case symbol.kind
    of nnkSym: return newDirectiveArg(ComponentDef(symbol), isPointer, kind)
    of nnkBracketExpr:
        case symbol[0].strVal
        of "Not": return parseDirectiveArg(symbol[1], isPointer, Exclude)
        of "Option": return parseDirectiveArg(symbol[1], isPointer, Optional)
        else: return newDirectiveArg(ComponentDef(symbol), isPointer, kind)
    of nnkIdentDefs: return parseDirectiveArg(symbol[1], isPointer, kind)
    of nnkPtrTy: return parseDirectiveArg(symbol[0], true, kind)
    else: error(&"Unexpected directive kind ({symbol.kind}): {symbol.repr}")

proc parseDirectiveArgsFromTuple(tupleArg: NimNode): seq[DirectiveArg] =
    ## Parses the symbols out of a tuple definition
    case tupleArg.kind:
    of nnkTupleConstr, nnkTupleTy:
        for child in tupleArg.children:
            result.add(parseDirectiveArg(child, false))
    of nnkSym:
        return parseDirectiveArgsFromTuple(tupleArg.getImpl)
    of nnkTypeDef:
        return parseDirectiveArgsFromTuple(tupleArg[2])
    else:
        error(&"Unexpected directive argument tuple: {tupleArg.repr}", tupleArg)

template orElse[T](optional: Option[T], exec: untyped): T =
    if optional.isSome: optional.get else: exec

proc parseParametricArg(
    parser: Parser,
    argName: string,
    directiveSymbol: NimNode,
    directiveParametric: NimNode
): Option[SystemArg] =
    ## Parses a system arg given a specific symbol and tuple
    let gen = parser.parseArgKind(directiveSymbol).orElse: return none(SystemArg)

    # Create a unique name for so the directives can be unique, if needed
    let uniqName = directiveSymbol.strVal & "_" & argName

    case gen.kind
    of DirectiveKind.Tuple:
        let tupleDir = newTupleDir(directiveParametric.parseDirectiveArgsFromTuple)
        return some(SystemArg(
            generator: gen,
            name: gen.chooseNameTuple(uniqName, tupleDir),
            kind: DirectiveKind.Tuple,
            tupleDir: tupleDir
        ))
    of DirectiveKind.Mono:
        let monoDir = newMonoDir(directiveParametric)
        return some(SystemArg(
            generator: gen,
            name: gen.chooseNameMono(uniqName, monoDir),
            kind: DirectiveKind.Mono,
            monoDir: monoDir
        ))
    of DirectiveKind.None:
        error("System argument does not support tuple parameters: " & $gen.kind)

proc parseFlagSystemArg(parser: Parser, directiveSymbol: NimNode): Option[SystemArg] =
    ## Parses unparameterized system args
    let gen = parser.parseArgKind(directiveSymbol).orElse: return none(SystemArg)
    case gen.kind
    of DirectiveKind.Tuple, DirectiveKind.Mono:
        error("System argument is not flag based: " & $gen.kind)
    of DirectiveKind.None:
        return some(SystemArg(generator: gen, kind: DirectiveKind.None))

proc parseArgType(parser: Parser, argName: string, argType, original: NimNode): SystemArg =
    ## Parses the type of a system argument

    var parsed: Option[SystemArg]
    case argType.kind:
    of nnkBracketExpr: parsed = parser.parseParametricArg(argName, argType[0], argType[1])
    of nnkCall: parsed = parser.parseParametricArg(argName, argType[1], argType[2])
    of nnkSym: parsed = parser.parseFlagSystemArg(argType)
    of nnkVarTy: parsed = some(parser.parseArgType(argName, argType[0], original))
    else: parsed = none(SystemArg)

    # If we were unable to parse the argument, it may be because it's a type alias. Lets try to resolve it
    if parsed.isNone:
        if argType.kind == nnkSym:
            let impl = argType.getImpl
            if impl.kind == nnkTypeDef:
                return parser.parseArgType(argName, impl[2], original)
        error("Expecting an ECS interface type, but got: " & original.repr, original)
    else:
        return parsed.get

proc parseSystemArg(parser: Parser, identDef: NimNode): SystemArg =
    ## Parses a SystemArg from a proc argument
    identDef.expectKind(nnkIdentDefs)
    return parser.parseArgType(identDef[0].strVal, identDef[1], identDef[1])

proc findChildSyms(node: NimNode, output: var seq[NimNode]) =
    ## Finds all symbols in the children of a node and returns them
    if node.kind == nnkSym:
        output.add(node)
    elif node.kind == nnkEmpty:
        discard
    elif node.len == 0:
        error("Expecting a system symbol, but got: " & node.repr, node)
    else:
        for child in node.children:
            findChildSyms(child, output)

proc findPragma(node: NimNode): NimNode =
    ## Finds the pragma node attached to a nim node
    case node.kind
    of nnkIdentDefs:
        if node[0].kind == nnkPragmaExpr:
            node[0][1]
        else:
            newEmptyNode()
    of nnkSym: newEmptyNode()
    else: node.pragma

proc readDependencies(typeNode: NimNode): seq[NimNode] =
    ## Reads the systems referenced by a pragma attached to another system
    let depends = bindSym("depends")
    for child in typeNode.findPragma:
        if child.kind == nnkCall and depends == child[0]:
            findChildSyms(child[1], result)

proc choosePhase(typeNode: NimNode, default: SystemPhase): SystemPhase =
    ## Reads the systems referenced by a pragma attached to another system

    let startupPragma = bindSym("startupSys")
    let loopSysPragma = bindSym("loopSys")
    let teardownSysPragma = bindSym("teardownSys")

    for child in typeNode.findPragma:
        if child.kind == nnkSym:
            if startupPragma == child:
                return StartupPhase
            elif loopSysPragma == child:
                return LoopPhase
            elif teardownSysPragma == child:
                return TeardownPhase
    return default

proc determineInstancing(nodeImpl: NimNode, nodeTypeImpl: NimNode): Option[NimNode] =
    ## Determines whether a system is instanced, and returns the type to use for instancing
    for child in nodeImpl.findPragma:
        if child == bindSym("instanced"):
            return some(nodeTypeImpl[0][0])

proc parseSystem(parser: Parser, ident: NimNode, phase: SystemPhase): ParsedSystem =
    ## Parses a single system proc
    ident.expectKind(nnkSym)

    let impl = ident.getImpl
    let typeImpl = ident.getTypeImpl

    # If we are given a proc, read the args directly from the proc. Otherwise, we need to
    # read them from the type, which is possibly less accurate
    let argSource = if impl.kind == nnkProcDef: impl.params else: typeImpl[0]

    let args = argSource.toSeq
        .filterIt(it.kind == nnkIdentDefs)
        .mapIt(parser.parseSystemArg(it))

    return ParsedSystem(
        phase: impl.choosePhase(phase),
        symbol: ident,
        args: args,
        depends: impl.readDependencies(),
        instanced: determineInstancing(impl, typeImpl)
    )

proc parseSystems(parser: Parser, systems: NimNode, phase: SystemPhase, into: var seq[ParsedSystem]) =
    # Recursively collects a list of systems
    case systems.kind
    of nnkSym:
        let parsed = parser.parseSystem(systems, phase)
        if into.allIt(it.symbol != parsed.symbol):
            for depends in parsed.depends:
                parser.parseSystems(depends, phase, into)
            into.add(parsed)
    of nnkPrefix:
        parser.parseSystems(systems[1], phase, into)
    of nnkBracket:
        for wrapped in systems.children:
            parseSystems(parser, wrapped, phase, into)
    else:
        systems.expectKind({nnkBracket, nnkPrefix, nnkSym})

proc parseSystemList*(parser: Parser, systems: NimNode, phase: SystemPhase): seq[ParsedSystem] =
    # Parses an list of system procs into a digesteable format
    systems.expectKind(nnkBracket)
    parser.parseSystems(systems, phase, result)

iterator components*(arg: SystemArg): ComponentDef =
    ## Pulls all components out of an argument
    case arg.kind
    of DirectiveKind.Tuple:
        for component in arg.tupleDir: yield component
    of DirectiveKind.Mono, DirectiveKind.None:
        discard

iterator components*(systems: openarray[ParsedSystem]): ComponentDef =
    ## Pulls all components from a list of parsed systems
    for system in systems:
        for arg in system.args:
            for component in arg.components:
                yield component

iterator args*(system: ParsedSystem): SystemArg =
    ## Yields all args in a system
    for arg in system.args: yield arg

iterator args*(systems: openarray[ParsedSystem]): SystemArg =
    ## Yields all args in a system
    for system in systems:
        for arg in system.args:
            yield arg

iterator components*(app: ParsedApp): ComponentDef =
    ## List all components referenced by an app
    for arg in app.runnerArgs:
        for component in arg.components:
            yield component

proc parseRunner(parser: Parser, runner: NimNode): seq[SystemArg] =
    ## Parses the arguments of the runner
    runner.expectKind(nnkSym)
    let impl = runner.getImpl

    # Verify that the last argument is a proc
    impl.params[^1][1].expectKind(nnkProcTy)

    result = impl.params.toSeq[1..^2].mapIt(parser.parseSystemArg(it))

proc parseApp*(parser: Parser, appProc: NimNode, runner: NimNode): ParsedApp =
    ## Parses the app proc
    result.name = appProc.name.strVal

    result.inputs = @[]
    for param in appProc.params[1..^1]:
        case param.kind
        of nnkEmpty: discard
        of nnkIdentDefs:
            param[0].expectKind(nnkIdent)
            param[1].expectKind(nnkIdent)
            result.inputs.add((param[0].strVal, newMonoDir(param[1])))
        else: param.expectKind({nnkEmpty, nnkIdentDefs})
    result.runnerArgs = parser.parseRunner(runner)

    let returnNode = appProc.params[0]
    result.returns = if returnNode.kind == nnkEmpty: none(MonoDirective) else: some(newMonoDir(returnNode))

proc instancedInfo*(system: ParsedSystem): Option[tuple[fieldName: NimNode, typ: NimNode]] =
    ## Returns details about the instancing configuration for a type
    system.instanced.map(proc (typ: auto): auto = (ident("instance_" & system.symbol.strVal), typ))