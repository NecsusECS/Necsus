import options, hashes, tables
import monoDirective, tupleDirective, archetypeBuilder, componentDef, worldEnum, directiveSet

type
    GenerateHook* = enum
        ## The different points at which code can be hooked
        Outside, Early, Standard, Late, BeforeLoop, LoopStart, LoopEnd

    AppInputs* = seq[tuple[argName: string, directive: MonoDirective]]
        ## The list of arguments passed into the app

    GenerateContext* {.byref.} = object
        ## Information passed in while performing code gen for a generator
        name*: string
        hook*: GenerateHook
        directives*: Table[DirectiveGen, DirectiveSet[SystemArg]]
        inputs*: AppInputs
        archetypes*: ArchetypeSet[ComponentDef]
        archetypeEnum*: ArchetypeEnum
    
    DirectiveKind* {.pure.} = enum
        Tuple, Mono, None

    DirectiveGen*  {.byref.} = object
        ## An object that can contribute to Necsus code generation
        ident*: string
        case kind*: DirectiveKind
        of DirectiveKind.Mono:
            parseMono*: proc(argName: string, component: NimNode): MonoDirective
            generateMono*: proc(details: GenerateContext, dir: MonoDirective): NimNode
            archetypeMono*: proc(builder: var ArchetypeBuilder[ComponentDef], dir: MonoDirective)
            chooseNameMono*: proc(uniqId: string, dir: MonoDirective): string
            systemReturn*: proc(args: DirectiveSet[SystemArg], returns: MonoDirective): Option[NimNode]
        of DirectiveKind.Tuple:
            parseTuple*: proc(components: seq[DirectiveArg]): TupleDirective
            generateTuple*: proc(details: GenerateContext, dir: TupleDirective): NimNode
            archetypeTuple*: proc(builder: var ArchetypeBuilder[ComponentDef], dir: TupleDirective)
            chooseNameTuple*: proc(uniqId: string, dir: TupleDirective): string
        of DirectiveKind.None:
            generateNone*: proc(details: GenerateContext): NimNode

    SystemArg* = object
        ## A single arg within a system proc
        generator*: DirectiveGen
        name*: string
        case kind*: DirectiveKind
        of DirectiveKind.Tuple:
            tupleDir*: TupleDirective
        of DirectiveKind.Mono:
            monoDir*: MonoDirective
        of DirectiveKind.None:
            discard

proc noArchetype[T](builder: var ArchetypeBuilder[ComponentDef], dir: T) = discard

proc defaultName(uniqId: string, dir: MonoDirective | TupleDirective): string = dir.generateName

proc newGenerator*(
    ident: string,
    parse: proc(components: seq[DirectiveArg]): TupleDirective,
    generate: proc(details: GenerateContext, dir: TupleDirective): NimNode,
    archetype: proc(builder: var ArchetypeBuilder[ComponentDef], dir: TupleDirective) = noArchetype,
    chooseName: proc(uniqId: string, dir: TupleDirective): string = defaultName
): DirectiveGen =
    ## Create a tuple based generator
    result.ident = ident
    result.kind = DirectiveKind.Tuple
    result.parseTuple = parse
    result.generateTuple = generate
    result.archetypeTuple = archetype
    result.chooseNameTuple = chooseName

proc defaultSystemReturn(args: DirectiveSet[SystemArg], returns: MonoDirective): Option[NimNode] = none(NimNode)

proc newGenerator*(
    ident: string,
    parse: proc(argName: string, component: NimNode): MonoDirective,
    generate: proc(details: GenerateContext, dir: MonoDirective): NimNode,
    archetype: proc(builder: var ArchetypeBuilder[ComponentDef], dir: MonoDirective) = noArchetype,
    chooseName: proc(uniqId: string, dir: MonoDirective): string = defaultName,
    systemReturn: proc(args: DirectiveSet[SystemArg], returns: MonoDirective): Option[NimNode] = defaultSystemReturn,
): DirectiveGen =
    ## Creates a mono based generator
    result.ident = ident
    result.kind = DirectiveKind.Mono
    result.parseMono = parse
    result.generateMono = generate
    result.archetypeMono = archetype
    result.chooseNameMono = chooseName
    result.systemReturn = systemReturn

proc newGenerator*(
    ident: string,
    generate: proc(details: GenerateContext): NimNode
): DirectiveGen =
    ## Creates a 'none' generator
    result.ident = ident
    result.kind = DirectiveKind.None
    result.generateNone = generate

proc `==`*(a, b: DirectiveGen): bool = a.ident == b.ident

proc hash*(gen: DirectiveGen): Hash = gen.ident.hash

proc `==`*(a, b: SystemArg): bool =
    if a.generator != b.generator or a.kind != b.kind or a.name != b.name:
        return false
    else:
        return case a.kind
        of DirectiveKind.Tuple: a.tupleDir == b.tupleDir
        of DirectiveKind.Mono: a.monoDir == b.monoDir
        of DirectiveKind.None: true

proc hash*(arg: SystemArg): Hash =
    result = arg.generator.hash !& arg.kind.hash !& arg.name.hash
    case arg.kind
    of DirectiveKind.Tuple: result = result !& arg.tupleDir.hash
    of DirectiveKind.Mono: result = result !& arg.monoDir.hash
    of DirectiveKind.None: discard

proc generateName*(arg: SystemArg): string =
    case arg.kind
    of DirectiveKind.Tuple, DirectiveKind.Mono: arg.name
    of DirectiveKind.None: arg.generator.ident

proc buildArchetype*(builder: var ArchetypeBuilder[ComponentDef], arg: SystemArg) =
    ## Generates the code for a specific hook
    case arg.kind
    of DirectiveKind.Tuple: arg.generator.archetypeTuple(builder, arg.tupleDir)
    of DirectiveKind.Mono: arg.generator.archetypeMono(builder, arg.monoDir)
    of DirectiveKind.None: discard

proc generateForHook*(arg: SystemArg, details: GenerateContext): NimNode =
    ## Generates the code for a specific hook
    case arg.kind
    of DirectiveKind.Tuple: arg.generator.generateTuple(details, arg.tupleDir)
    of DirectiveKind.Mono: arg.generator.generateMono(details, arg.monoDir)
    of DirectiveKind.None: arg.generator.generateNone(details)