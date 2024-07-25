import std/[options, hashes, tables, macros, strformat, strutils, sequtils, macrocache]
import archetype, dualDirective, monoDirective, tupleDirective, archetypeBuilder
import componentDef, worldEnum, directiveSet, common, directiveArg

type
    GenerateHook* = enum
        ## The different points at which code can be hooked
        Outside, Standard, Late, BeforeLoop, LoopStart, AfterActiveCheck, LoopEnd

    AppInputs* = seq[tuple[argName: string, directive: MonoDirective]]
        ## The list of arguments passed into the app

    GenerateContext* = ref object
        ## Information passed in while performing code gen for a generator
        hook*: GenerateHook
        directives*: Table[DirectiveGen, DirectiveSet[SystemArg]]
        inputs*: AppInputs
        archetypes*: ArchetypeSet[ComponentDef]
        archetypeEnum*: ArchetypeEnum
        appStateTypeName*: NimNode

    DirectiveKind* {.pure.} = enum
        Dual, Tuple, Mono, None

    WorldField* = tuple[name: string, typ: NimNode]
        ## A field to add to the world object

    RawNestedArg* = tuple[name: NimNode, directive: NimNode]
        ## A field to add to the world object

    NestedArgsExtractor*[T] = proc(dir: T): seq[RawNestedArg]
        ## Callback that pulls out any nested arguments also required by this directive

    HookGenerator*[T] = proc(details: GenerateContext, arg: SystemArg, name: string, dir: T): NimNode
        ## The callback that allows a decorator to generate code for a specific hook

    NameChooser*[T] = proc(context, name: NimNode; dir: T): string
        ## Picks the name for an argument

    SystemArgExtractor*[T] = proc(name: string, dir: T): NimNode
        ## The callback used for determining the value to pass when calling the system

    ConverterDef* = ref object
        ## Defines a function for converting from one tuple shape to another
        input*: seq[ComponentDef]
        adding*: seq[ComponentDef]
        output*: TupleDirective
        sinkParams*: bool
        signatureCache: string

    ConvertExtractor*[T] = proc(context: GenerateContext, dir: T): seq[ConverterDef]
        ## The callback for determining what converters to execute

    BuildArchetype*[T] = proc(builder: var ArchetypeBuilder[ComponentDef], systemArgs: seq[SystemArg], dir: T)
        ## A callback used to construct an archetype

    DirectiveGen* = ref object
        ## An object that can contribute to Necsus code generation
        ident*: string
        cachedHash: Hash
        interest*: set[GenerateHook]
        case kind*: DirectiveKind
        of DirectiveKind.Mono:
            generateMono*: HookGenerator[MonoDirective]
            archetypeMono*: BuildArchetype[MonoDirective]
            chooseNameMono*: NameChooser[MonoDirective]
            systemReturn*: proc(args: DirectiveSet[SystemArg], returns: MonoDirective): Option[NimNode]
            worldFieldsMono*: proc(name: string, returns: MonoDirective): seq[WorldField]
            systemArgMono*: SystemArgExtractor[MonoDirective]
            nestedArgsMono*: NestedArgsExtractor[MonoDirective]
        of DirectiveKind.Tuple:
            generateTuple*: HookGenerator[TupleDirective]
            archetypeTuple*: BuildArchetype[TupleDirective]
            chooseNameTuple*: NameChooser[TupleDirective]
            worldFieldsTuple*: proc(name: string, returns: TupleDirective): seq[WorldField]
            systemArgTuple*: SystemArgExtractor[TupleDirective]
            nestedArgsTuple*: NestedArgsExtractor[TupleDirective]
            convertersTuple*: ConvertExtractor[TupleDirective]
        of DirectiveKind.None:
            generateNone*: HookGenerator[void]
            worldFieldsNone: proc(name: string): seq[WorldField]
            systemArgNone*: SystemArgExtractor[void]
        of DirectiveKind.Dual:
            generateDual*: HookGenerator[DualDirective]
            archetypeDual*: BuildArchetype[DualDirective]
            chooseNameDual*: NameChooser[DualDirective]
            worldFieldsDual*: proc(name: string, returns: DualDirective): seq[WorldField]
            systemArgDual*: SystemArgExtractor[DualDirective]
            nestedArgsDual*: NestedArgsExtractor[DualDirective]
            convertersDual*: ConvertExtractor[DualDirective]

    SystemArg* = ref object
        ## A single arg within a system proc
        source*: NimNode
        generator*: DirectiveGen
        originalName*: string
        name*: string
        cachedHash: Hash
        case kind*: DirectiveKind
        of DirectiveKind.Tuple:
            tupleDir*: TupleDirective
        of DirectiveKind.Mono:
            monoDir*: MonoDirective
        of DirectiveKind.None:
            discard
        of DirectiveKind.Dual:
            dualDir*: DualDirective
        nestedArgs*: seq[SystemArg]

proc newConverter*(
    input: Archetype[ComponentDef],
    adding: seq[ComponentDef],
    output: Archetype[ComponentDef],
    sinkParams: bool
): ConverterDef =
    ConverterDef(input: input.values, adding: adding, output: newTupleDir(output.values), sinkParams: sinkParams)

proc newConverter*(input: Archetype[ComponentDef], output: TupleDirective): ConverterDef =
    ConverterDef(input: input.values, output: output)

proc noArchetype[T](builder: var ArchetypeBuilder[ComponentDef], systemArgs: seq[SystemArg], dir: T) = discard

proc defaultName(context, argName: NimNode, dir: MonoDirective | TupleDirective | DualDirective): string = dir.name

proc defaultWorldField(name: string, dir: MonoDirective | TupleDirective | DualDirective): seq[WorldField] = @[]

proc defaultSystemArg(name: string, dir: MonoDirective | TupleDirective | DualDirective): NimNode =
    newDotExpr(appStateIdent, name.ident)

proc defaultNestedArgs(dir: MonoDirective | TupleDirective | DualDirective): seq[RawNestedArg] = @[]

proc defaultConverters(context: GenerateContext, dir: TupleDirective | DualDirective): seq[ConverterDef] = @[]

proc newGenerator*(
    ident: string,
    interest: set[GenerateHook],
    generate: HookGenerator[TupleDirective],
    archetype: BuildArchetype[TupleDirective] = noArchetype,
    chooseName: NameChooser[TupleDirective] = defaultName,
    worldFields: proc(name: string, dir: TupleDirective): seq[WorldField] = defaultWorldField,
    systemArg: SystemArgExtractor[TupleDirective] = defaultSystemArg,
    nestedArgs: NestedArgsExtractor[TupleDirective] = defaultNestedArgs,
    converters: ConvertExtractor[TupleDirective] = defaultConverters,
): DirectiveGen =
    ## Create a tuple based generator
    result.new
    result.ident = ident
    result.interest = interest
    result.cachedHash = hash(ident)
    result.kind = DirectiveKind.Tuple
    result.generateTuple = generate
    result.archetypeTuple = archetype
    result.chooseNameTuple = chooseName
    result.worldFieldsTuple = worldFields
    result.systemArgTuple = systemArg
    result.nestedArgsTuple = nestedArgs
    result.convertersTuple = converters

proc defaultSystemReturn(args: DirectiveSet[SystemArg], returns: MonoDirective): Option[NimNode] = none(NimNode)

proc newGenerator*(
    ident: string,
    interest: set[GenerateHook],
    generate: HookGenerator[MonoDirective],
    archetype: BuildArchetype[MonoDirective] = noArchetype,
    chooseName: NameChooser[MonoDirective] = defaultName,
    systemReturn: proc(args: DirectiveSet[SystemArg], returns: MonoDirective): Option[NimNode] = defaultSystemReturn,
    worldFields: proc(name: string, dir: MonoDirective): seq[WorldField] = defaultWorldField,
    systemArg: SystemArgExtractor[MonoDirective] = defaultSystemArg,
    nestedArgs: NestedArgsExtractor[MonoDirective] = defaultNestedArgs,
): DirectiveGen =
    ## Creates a mono based generator
    result.new
    result.ident = ident
    result.interest = interest
    result.kind = DirectiveKind.Mono
    result.generateMono = generate
    result.archetypeMono = archetype
    result.chooseNameMono = chooseName
    result.systemReturn = systemReturn
    result.worldFieldsMono = worldFields
    result.systemArgMono = systemArg
    result.nestedArgsMono = nestedArgs

proc defaultWorldFieldNone(name: string): seq[WorldField] = @[]

proc defaultSystemArgNone(name: string): NimNode = newDotExpr(appStateIdent, name.ident)

proc newGenerator*(
    ident: string,
    interest: set[GenerateHook],
    generate: HookGenerator[void],
    worldFields: proc(name: string): seq[WorldField] = defaultWorldFieldNone,
    systemArg: SystemArgExtractor[void] = defaultSystemArgNone,
): DirectiveGen =
    ## Creates a 'none' generator
    result.new
    result.ident = ident
    result.interest = interest
    result.kind = DirectiveKind.None
    result.generateNone = generate
    result.worldFieldsNone = worldFields
    result.systemArgNone = systemArg

proc newGenerator*(
    ident: string,
    interest: set[GenerateHook],
    generate: HookGenerator[DualDirective],
    archetype: BuildArchetype[DualDirective] = noArchetype,
    chooseName: NameChooser[DualDirective] = defaultName,
    worldFields: proc(name: string, dir: DualDirective): seq[WorldField] = defaultWorldField,
    systemArg: SystemArgExtractor[DualDirective] = defaultSystemArg,
    nestedArgs: NestedArgsExtractor[DualDirective] = defaultNestedArgs,
    converters: ConvertExtractor[DualDirective] = defaultConverters,
): DirectiveGen =
    ## Create a tuple based generator
    return DirectiveGen(
        ident: ident,
        interest: interest,
        cachedHash: hash(ident),
        kind: DirectiveKind.Dual,
        generateDual: generate,
        archetypeDual: archetype,
        chooseNameDual: chooseName,
        worldFieldsDual: worldFields,
        systemArgDual: systemArg,
        nestedArgsDual: nestedArgs,
        convertersDual: converters,
    )

proc `==`*(a, b: DirectiveGen): bool = a.ident == b.ident

proc hash*(gen: DirectiveGen): Hash = gen.cachedHash

proc newSystemArg*[T : TupleDirective | MonoDirective | DualDirective | void](
    source: NimNode,
    generator: DirectiveGen,
    originalName: string,
    name: string,
    nestedArgs: seq[SystemArg] = @[],
    directive: T,
): SystemArg =
    ## Instantiates a SystemArg
    result.new
    result.source = source
    result.generator = generator
    result.originalName = originalName
    result.name = name
    result.nestedArgs = nestedArgs

    let baseHash = generator.hash !& name.hash
    when T is TupleDirective:
        result.kind = DirectiveKind.Tuple
        result.tupleDir = directive
        result.cachedHash = baseHash !& directive.hash
    elif T is MonoDirective:
        result.kind = DirectiveKind.Mono
        result.monoDir = directive
        result.cachedHash = baseHash !& directive.hash
    elif T is DualDirective:
        result.kind = DirectiveKind.Dual
        result.dualDir = directive
        result.cachedHash = baseHash !& directive.hash
    else:
        result.kind = DirectiveKind.None
        result.cachedHash = baseHash

proc `$`*(arg: SystemArg): string =
    let directive = case arg.kind
        of DirectiveKind.Tuple: $arg.tupleDir
        of DirectiveKind.Mono: $arg.monoDir
        of DirectiveKind.Dual: $arg.dualDir
        of DirectiveKind.None: "none"
    let nestedStr = arg.nestedArgs.mapIt($it).join(", ")
    &"{arg.originalName}({arg.generator.ident}, name: {arg.name}, {arg.kind}: {directive}, nested: [{nestedStr}])"

proc `==`*(a, b: SystemArg): bool =
    if a.generator != b.generator or a.kind != b.kind or a.name != b.name:
        return false
    else:
        return case a.kind
        of DirectiveKind.Tuple: a.tupleDir == b.tupleDir
        of DirectiveKind.Mono: a.monoDir == b.monoDir
        of DirectiveKind.Dual: a.dualDir == b.dualDir
        of DirectiveKind.None: true

proc hash*(arg: SystemArg): Hash = arg.cachedHash

proc generateName*(arg: SystemArg): string =
    case arg.kind
    of DirectiveKind.Tuple, DirectiveKind.Mono, DirectiveKind.Dual: arg.name
    of DirectiveKind.None: arg.generator.ident

proc buildArchetype*(builder: var ArchetypeBuilder[ComponentDef], systemArgs: seq[SystemArg], arg: SystemArg) =
    ## Generates the code for a specific hook
    try:
        case arg.kind
        of DirectiveKind.Tuple: arg.generator.archetypeTuple(builder, systemArgs, arg.tupleDir)
        of DirectiveKind.Mono: arg.generator.archetypeMono(builder, systemArgs, arg.monoDir)
        of DirectiveKind.Dual: arg.generator.archetypeDual(builder, systemArgs, arg.dualDir)
        of DirectiveKind.None: discard
    except UnsortedArchetype as e:
        error(e.msg, arg.source)

proc generateForHook*(arg: SystemArg, details: GenerateContext, name: string): NimNode =
    ## Generates the code for a specific hook
    case arg.kind
    of DirectiveKind.Tuple: arg.generator.generateTuple(details, arg, name, arg.tupleDir)
    of DirectiveKind.Mono: arg.generator.generateMono(details, arg, name, arg.monoDir)
    of DirectiveKind.Dual: arg.generator.generateDual(details, arg, name, arg.dualDir)
    of DirectiveKind.None: arg.generator.generateNone(details, arg, name)

proc worldFields*(arg: SystemArg, name: string): seq[WorldField] =
    ## Generates the code for a specific hook
    case arg.kind
    of DirectiveKind.Tuple: arg.generator.worldFieldsTuple(name, arg.tupleDir)
    of DirectiveKind.Mono: arg.generator.worldFieldsMono(name, arg.monoDir)
    of DirectiveKind.Dual: arg.generator.worldFieldsDual(name, arg.dualDir)
    of DirectiveKind.None: arg.generator.worldFieldsNone(name)

proc converters*(ctx: GenerateContext, arg: SystemArg): seq[ConverterDef] =
    ## Returns a list of all the convertsers needed by a system
    case arg.kind
    of DirectiveKind.Tuple: return arg.generator.convertersTuple(ctx, arg.tupleDir)
    of DirectiveKind.Dual: return arg.generator.convertersDual(ctx, arg.dualDir)
    of DirectiveKind.Mono, DirectiveKind.None: return @[]

proc systemArg(arg: SystemArg, name: string): NimNode =
    ## Generates the argument to pass in when calling a system
    case arg.kind
    of DirectiveKind.Tuple: arg.generator.systemArgTuple(name, arg.tupleDir)
    of DirectiveKind.Mono: arg.generator.systemArgMono(name, arg.monoDir)
    of DirectiveKind.Dual: arg.generator.systemArgDual(name, arg.dualDir)
    of DirectiveKind.None: arg.generator.systemArgNone(name)

proc nameOf*(ctx: GenerateContext, arg: SystemArg): string =
    ## Returns the name used for a system arg
    ctx.directives[arg.generator].nameOf(arg)

proc systemArg*(directives: Table[DirectiveGen, DirectiveSet[SystemArg]], arg: SystemArg): NimNode =
    ## Returns the value to pass to a system when executin the given argument
    systemArg(arg, directives[arg.generator].nameOf(arg))

proc systemArg*(ctx: GenerateContext, arg: SystemArg): NimNode =
    ## Returns the value to pass to a system when executin the given argument
    systemArg(ctx.directives, arg)

proc globalName*(ctx: GenerateContext, name: string): NimNode =
    ## Generates a deterministic name for a global identifier
    ident(ctx.appStateTypeName.strVal & "_" & name)

proc allNestedArgs(arg: SystemArg, into: var seq[SystemArg]) =
    for nested in arg.nestedArgs:
        allNestedArgs(nested, into)
        into.add(nested)

iterator allArgs*(args: openArray[SystemArg]): SystemArg =
    # Yield any system args nested inside other system args
    for arg in args:
        var collectNested: seq[SystemArg]
        arg.allNestedArgs(collectNested)
        for nested in collectNested:
            yield nested

        yield arg

proc sendEventProcName*(directive: MonoDirective): NimNode =
    ## Generates the proc name for sending an event to all listening inboxes
    ident("send" & directive.name.capitalizeAscii)

iterator nodes*(arg: SystemArg): NimNode =
    ## Pulls all nodes out of an arg
    case arg.kind
    of DirectiveKind.Tuple:
        for component in arg.tupleDir: yield component.node
    of DirectiveKind.Dual:
        for component in arg.dualDir: yield component.node
    of DirectiveKind.Mono:
        yield arg.monoDir.argType
    of DirectiveKind.None:
        discard


when NimMajor >= 2:
    const converterNames = CacheTable("NecsusConverterName")
else:
    import std/tables
    var converterNames {.compileTime.} = initTable[string, NimNode]()

proc signature*(conv: ConverterDef): string =
    ## Produces a globally unique signature for a converter
    if conv.signatureCache == "":
        if conv.sinkParams:
            result = "SINK_"

        for comp in conv.input:
            result.addSignature(comp)

        result &= "_WITH_"
        for comp in conv.adding:
            result.addSignature(comp)

        result &= "_TO_"
        for arg in conv.output.args:
            result.addSignature(arg)

        conv.signatureCache = result
    else:
        return conv.signatureCache

proc name*(convert: ConverterDef): NimNode =
    ## Returns the name for referencing a `ConverterDef`
    let signature = convert.signature
    if signature notin converterNames:
        converterNames[signature] = genSym(nskProc, "conv")
    return converterNames[signature]
