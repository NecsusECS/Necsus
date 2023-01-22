import worldEnum, parse, componentDef, archetypeBuilder, systemGen, directiveSet
import macros, sequtils, options, sets, tables, strutils

type CodeGenInfo*  {.byref.} = object
    ## Contains all the information needed to do high level code gen
    config*: NimNode
    app*: ParsedApp
    systems*: seq[ParsedSystem]
    directives*: Table[DirectiveGen, DirectiveSet[SystemArg]]
    archetypes*: ArchetypeSet[ComponentDef]
    archetypeEnum*: ArchetypeEnum

proc calculateArchetypes(args: openarray[SystemArg]): ArchetypeSet[ComponentDef] =
    ## Given all the directives, creates a set of required archetypes
    var builder = newArchetypeBuilder[ComponentDef]()
    for arg in args:
        builder.buildArchetype(arg)
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

proc newCodeGenInfo*(
    config: NimNode,
    app: ParsedApp,
    allSystems: openarray[ParsedSystem]
): CodeGenInfo =
    ## Collects data needed for code gen from all the parsed systems
    result.config = config
    result.app = app
    result.systems = allSystems.toSeq

    let allArgs = app.runnerArgs.concat(allSystems.args.toSeq)

    result.archetypes = allArgs.calculateArchetypes()
    result.archetypeEnum = archetypeEnum(app.name, result.archetypes)
    result.directives = allArgs.calculateDirectives()

proc appStateTypeName*(genInfo: CodeGenInfo): NimNode =
    ## The name of the object that contains the state of the app
    ident(genInfo.app.name & "State")

proc appStateInit*(genInfo: CodeGenInfo): NimNode =
    ## The name of the object that contains the state of the app
    ident("init" & genInfo.app.name.capitalizeAscii)

proc generateForHook*(codeGen: CodeGenInfo, hook: GenerateHook): NimNode =
    ## Generates the code for a specific code-gen hook
    result = newStmtList()
    for _, argSet in codeGen.directives:
        for name, arg in argSet:
            let details = GenerateContext(
                name: name,
                hook: hook,
                inputs: codeGen.app.inputs,
                directives: codeGen.directives,
                archetypes: codeGen.archetypes,
                archetypeEnum: codeGen.archetypeEnum
            )
            result.add(arg.generateForHook(details))

proc worldFields*(codeGen: CodeGenInfo): seq[WorldField] =
    ## Generates the code for a specific code-gen hook
    for _, argSet in codeGen.directives:
        for name, arg in argSet:
            result.add(arg.worldFields(name))