import macros, componentSet, parse, directiveSet, directive, sequtils, componentDef

type CodeGenInfo* = object
    ## Contains all the information needed to do high level code gen
    config*: NimNode
    systems*: seq[ParsedSystem]
    components*: ComponentSet
    queries*: DirectiveSet[QueryDef]
    spawns*: DirectiveSet[SpawnDef]
    updates*: DirectiveSet[UpdateDef]

proc newCodeGenInfo*(name: NimNode, config: NimNode, allSystems: openarray[ParsedSystem]): CodeGenInfo =
    ## Collects data needed for code gen from all the parsed systems
    CodeGenInfo(
        config: config,
        systems: allSystems.toSeq,
        components: allSystems.componentSet(name.strVal),
        queries: newDirectiveSet[QueryDef](name.strVal, allSystems.queries.toSeq),
        spawns: newDirectiveSet[SpawnDef](name.strVal, allSystems.spawns.toSeq),
        updates: newDirectiveSet[UpdateDef](name.strVal, allSystems.updates.toSeq)
    )

proc componentEnumVal*(components: ComponentSet, component: ComponentDef): NimNode =
    ## Creates a reference to a component enum value
    nnkDotExpr.newTree(components.enumSymbol, component.ident)

proc asTupleType*(args: openarray[DirectiveArg]): NimNode =
    ## Creates a tuple type from a list of components
    result = nnkTupleConstr.newTree()
    for arg in args:
        result.add(if arg.isPointer: nnkPtrTy.newTree(arg.component.ident) else: arg.component.ident)

## Returns the identity needed to access the components field
let componentsIdent* {.compileTime.} = ident("components")

## The variable used to reference the initial size of any structs
let confIdent* {.compileTime.} = ident("config")

## The variable for identifying the local world
let worldIdent* {.compileTime.} = ident("world")

## The method for deleting entities
let deleteProc* {.compileTime.} = ident("deleteEntity")
