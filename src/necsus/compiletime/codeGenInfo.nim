import worldEnum, parse, componentDef, archetypeBuilder, systemGen, directiveSet
import macros, sequtils, sets, tables, strutils

type CodeGenInfo* = ref object
    ## Contains all the information needed to do high level code gen
    config*: NimNode
    app*: ParsedApp
    systems*: seq[ParsedSystem]
    directives*: Table[DirectiveGen, DirectiveSet[SystemArg]]
    archetypes*: ArchetypeSet[ComponentDef]
    archetypeEnum*: ArchetypeEnum

proc calculateArchetypes(allSystems: openarray[ParsedSystem], runnerArgs: seq[SystemArg]): ArchetypeSet[ComponentDef] =
    ## Given all the directives, creates a set of required archetypes
    var builder = newArchetypeBuilder[ComponentDef]()
    for arg in runnerArgs:
        builder.buildArchetype(runnerArgs, arg)
    for system in allSystems:
        for arg in system.allArgs:
            builder.buildArchetype(system.args, arg)
    return builder.build()

proc calculateDirectives(args: openarray[SystemArg]): Table[DirectiveGen, DirectiveSet[SystemArg]] =
    ## Collects a table of unique directives
    var grouped = initTable[DirectiveGen, seq[SystemArg]]()
    for arg in args:
        discard grouped.hasKeyOrPut(arg.generator, @[])
        grouped[arg.generator].add(arg)

    result = initTable[DirectiveGen, DirectiveSet[SystemArg]]()
    for gen, args in grouped:
        result[gen] = newDirectiveSet[SystemArg](gen.ident, args)

proc profilingEnabled*(): bool =
    ## Returns whether to inject system profiling code
    defined(profile)

proc newEmptyCodeGenInfo*(config: NimNode, app: ParsedApp): CodeGenInfo =
    ## Collects data needed for code gen from all the parsed systems
    let archetypes = newArchetypeBuilder[ComponentDef]().build()
    return CodeGenInfo(
        config: config,
        app: app,
        systems: @[],
        archetypes: archetypes,
        archetypeEnum: archetypeEnum(app.name, archetypes),
        directives: initTable[DirectiveGen, DirectiveSet[SystemArg]]()
    )

proc newCodeGenInfo*(
    config: NimNode,
    app: ParsedApp,
    allSystems: openarray[ParsedSystem]
): CodeGenInfo =
    ## Collects data needed for code gen from all the parsed systems
    result = CodeGenInfo(config: config, app: app, systems: allSystems.toSeq)

    let allArgs = app.runnerArgs.concat(allSystems.args.toSeq)

    result.archetypes = allSystems.calculateArchetypes(app.runnerArgs)
    result.archetypeEnum = archetypeEnum(app.name, result.archetypes)
    result.directives = allArgs.calculateDirectives()

proc appStateStruct*(genInfo: CodeGenInfo): NimNode =
    ## The name of the raw struct fo an app state object
    ident(genInfo.app.name & "Struct")

proc appStateTypeName*(genInfo: CodeGenInfo): NimNode =
    ## The name of the object that contains the state of the app
    ident(genInfo.app.name & "State")

proc appStateInit*(genInfo: CodeGenInfo): NimNode =
    ## The name of the object that contains the state of the app
    ident("init" & genInfo.app.name.capitalizeAscii)

proc newGenerateContext(codeGen: CodeGenInfo, hook: GenerateHook): GenerateContext =
    ## Create a GenerateContext for a hook
    return GenerateContext(
        hook: hook,
        inputs: codeGen.app.inputs,
        directives: codeGen.directives,
        archetypes: codeGen.archetypes,
        archetypeEnum: codeGen.archetypeEnum,
        appStateTypeName: codeGen.appStateTypeName
    )

proc nameOf*(genInfo: CodeGenInfo, arg: SystemArg): string =
    ## Returns the name used for a specific system arg
    genInfo.directives[arg.generator].nameOf(arg)

proc generateForHook*(codeGen: CodeGenInfo, system: ParsedSystem, hook: GenerateHook): NimNode =
    ## Generates the code for a specific code-gen hook
    result = newStmtList()
    var details: GenerateContext
    for arg in system.allArgs:
        if hook in arg.generator.interest:
            if details == nil:
                details = newGenerateContext(codeGen, hook)
            result.add(arg.generateForHook(details, codeGen.nameOf(arg)))

proc generateForHook*(codeGen: CodeGenInfo, hook: GenerateHook): NimNode =
    ## Generates the code for a specific code-gen hook
    result = newStmtList()
    var details: GenerateContext
    for _, argSet in codeGen.directives:
        for name, arg in argSet:
            if hook in arg.generator.interest:
                if details == nil:
                    details = newGenerateContext(codeGen, hook)
                result.add(arg.generateForHook(details, name))

proc worldFields*(codeGen: CodeGenInfo): seq[WorldField] =
    ## Generates the code for a specific code-gen hook
    for _, argSet in codeGen.directives:
        for name, arg in argSet:
            result.add(arg.worldFields(name))

proc systemArg*(genInfo: CodeGenInfo, arg: SystemArg): NimNode =
    ## Returns the value to pass to a system when executin the given argument
    systemArg(genInfo.directives, arg)