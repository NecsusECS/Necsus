import options, hashes, tables, macros, archetype, strformat, strutils, sequtils
import monoDirective, tupleDirective, archetypeBuilder, componentDef, worldEnum, directiveSet, commonVars

type
    GenerateHook* = enum
        ## The different points at which code can be hooked
        Outside, Early, Standard, Late, BeforeLoop, LoopStart, AfterSystem, LoopEnd, BeforeTeardown

    AppInputs* = seq[tuple[argName: string, directive: MonoDirective]]
        ## The list of arguments passed into the app

    GenerateContext* = ref object
        ## Information passed in while performing code gen for a generator
        hook*: GenerateHook
        directives*: Table[DirectiveGen, DirectiveSet[SystemArg]]
        inputs*: AppInputs
        archetypes*: ArchetypeSet[ComponentDef]
        archetypeEnum*: ArchetypeEnum

    DirectiveKind* {.pure.} = enum
        Tuple, Mono, None

    WorldField* = tuple[name: string, typ: NimNode]
        ## A field to add to the world object

    RawNestedArg* = tuple[name: NimNode, directive: NimNode]
        ## A field to add to the world object

    NestedArgsExtractor*[T] = proc(dir: T): seq[RawNestedArg]
        ## Callback that pulls out any nested arguments also required by this directive

    HookGenerator*[T] = proc(details: GenerateContext, arg: SystemArg, name: string, dir: T): NimNode
        ## The callback that allows a decorator to generate code for a specific hook

    NameChooser*[T] = proc(name: NimNode, dir: T): string
        ## Picks the name for an argument

    SystemArgExtractor*[T] = proc(name: string, dir: T): NimNode
        ## The callback used for determining the value to pass when calling the system

    DirectiveGen* = ref object
        ## An object that can contribute to Necsus code generation
        ident*: string
        cachedHash: Hash
        interest*: set[GenerateHook]
        case kind*: DirectiveKind
        of DirectiveKind.Mono:
            generateMono*: HookGenerator[MonoDirective]
            archetypeMono*: proc(builder: var ArchetypeBuilder[ComponentDef], dir: MonoDirective)
            chooseNameMono*: NameChooser[MonoDirective]
            systemReturn*: proc(args: DirectiveSet[SystemArg], returns: MonoDirective): Option[NimNode]
            worldFieldsMono*: proc(name: string, returns: MonoDirective): seq[WorldField]
            systemArgMono*: SystemArgExtractor[MonoDirective]
            nestedArgsMono*: NestedArgsExtractor[MonoDirective]
        of DirectiveKind.Tuple:
            generateTuple*: HookGenerator[TupleDirective]
            archetypeTuple*: proc(builder: var ArchetypeBuilder[ComponentDef], dir: TupleDirective)
            chooseNameTuple*: NameChooser[TupleDirective]
            worldFieldsTuple*: proc(name: string, returns: TupleDirective): seq[WorldField]
            systemArgTuple*: SystemArgExtractor[TupleDirective]
            nestedArgsTuple*: NestedArgsExtractor[TupleDirective]
        of DirectiveKind.None:
            generateNone*: HookGenerator[void]
            worldFieldsNone: proc(name: string): seq[WorldField]
            systemArgNone*: SystemArgExtractor[void]

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
        nestedArgs*: seq[SystemArg]

proc noArchetype[T](builder: var ArchetypeBuilder[ComponentDef], dir: T) = discard

proc defaultName(argName: NimNode, dir: MonoDirective | TupleDirective): string = dir.name

proc defaultWorldField(name: string, dir: MonoDirective | TupleDirective): seq[WorldField] = @[]

proc defaultSystemArg(name: string, dir: MonoDirective | TupleDirective): NimNode =
    newDotExpr(appStateIdent, name.ident)

proc defaultNestedArgs(dir: MonoDirective | TupleDirective): seq[RawNestedArg] = @[]

proc newGenerator*(
    ident: string,
    interest: set[GenerateHook],
    generate: HookGenerator[TupleDirective],
    archetype: proc(builder: var ArchetypeBuilder[ComponentDef], dir: TupleDirective) = noArchetype,
    chooseName: NameChooser[TupleDirective] = defaultName,
    worldFields: proc(name: string, dir: TupleDirective): seq[WorldField] = defaultWorldField,
    systemArg: SystemArgExtractor[TupleDirective] = defaultSystemArg,
    nestedArgs: NestedArgsExtractor[TupleDirective] = defaultNestedArgs,
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

proc defaultSystemReturn(args: DirectiveSet[SystemArg], returns: MonoDirective): Option[NimNode] = none(NimNode)

proc newGenerator*(
    ident: string,
    interest: set[GenerateHook],
    generate: HookGenerator[MonoDirective],
    archetype: proc(builder: var ArchetypeBuilder[ComponentDef], dir: MonoDirective) = noArchetype,
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

proc `==`*(a, b: DirectiveGen): bool = a.ident == b.ident

proc hash*(gen: DirectiveGen): Hash = gen.cachedHash

proc newSystemArg*[T : TupleDirective | MonoDirective | void](
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
    else:
        result.kind = DirectiveKind.None
        result.cachedHash = baseHash

proc `$`*(arg: SystemArg): string =
    let directive = case arg.kind
        of DirectiveKind.Tuple: $arg.tupleDir
        of DirectiveKind.Mono: $arg.monoDir
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
        of DirectiveKind.None: true

proc hash*(arg: SystemArg): Hash = arg.cachedHash

proc generateName*(arg: SystemArg): string =
    case arg.kind
    of DirectiveKind.Tuple, DirectiveKind.Mono: arg.name
    of DirectiveKind.None: arg.generator.ident

proc buildArchetype*(builder: var ArchetypeBuilder[ComponentDef], arg: SystemArg) =
    ## Generates the code for a specific hook
    try:
        case arg.kind
        of DirectiveKind.Tuple: arg.generator.archetypeTuple(builder, arg.tupleDir)
        of DirectiveKind.Mono: arg.generator.archetypeMono(builder, arg.monoDir)
        of DirectiveKind.None: discard
    except UnsortedArchetype as e:
        error(e.msg, arg.source)

proc generateForHook*(arg: SystemArg, details: GenerateContext, name: string): NimNode =
    ## Generates the code for a specific hook
    case arg.kind
    of DirectiveKind.Tuple: arg.generator.generateTuple(details, arg, name, arg.tupleDir)
    of DirectiveKind.Mono: arg.generator.generateMono(details, arg, name, arg.monoDir)
    of DirectiveKind.None: arg.generator.generateNone(details, arg, name)

proc worldFields*(arg: SystemArg, name: string): seq[WorldField] =
    ## Generates the code for a specific hook
    case arg.kind
    of DirectiveKind.Tuple: arg.generator.worldFieldsTuple(name, arg.tupleDir)
    of DirectiveKind.Mono: arg.generator.worldFieldsMono(name, arg.monoDir)
    of DirectiveKind.None: arg.generator.worldFieldsNone(name)

proc systemArg(arg: SystemArg, name: string): NimNode =
    ## Generates the argument to pass in when calling a system
    case arg.kind
    of DirectiveKind.Tuple: arg.generator.systemArgTuple(name, arg.tupleDir)
    of DirectiveKind.Mono: arg.generator.systemArgMono(name, arg.monoDir)
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