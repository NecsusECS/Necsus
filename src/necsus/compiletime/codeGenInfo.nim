import macros, componentSet, parse, directiveSet, directive, sequtils, componentDef

type CodeGenInfo* = object
    ## Contains all the information needed to do high level code gen
    initialSize: NimNode
    systems*: seq[ParsedSystem]
    components*: ComponentSet
    queries*: DirectiveSet[QueryDef]
    spawns*: DirectiveSet[SpawnDef]
    updates*: DirectiveSet[UpdateDef]

proc newCodeGenInfo*(name: NimNode, initialSize: NimNode, allSystems: openarray[ParsedSystem]): CodeGenInfo =
    ## Collects data needed for code gen from all the parsed systems
    CodeGenInfo(
        initialSize: initialSize,
        systems: allSystems.toSeq,
        components: allSystems.componentSet(name.strVal),
        queries: newDirectiveSet[QueryDef](name.strVal, allSystems.queries.toSeq),
        spawns: newDirectiveSet[SpawnDef](name.strVal, allSystems.spawns.toSeq),
        updates: newDirectiveSet[UpdateDef](name.strVal, allSystems.updates.toSeq)
    )

proc componentEnumVal*(components: ComponentSet, component: ComponentDef): NimNode =
    ## Creates a reference to a component enum value
    nnkDotExpr.newTree(components.enumSymbol, component.ident)

proc asTupleType*(components: seq[ComponentDef]): NimNode =
    ## Creates a tuple type from a list of components
    nnkTupleConstr.newTree(components.mapIt(it.ident))

## Returns the identity needed to access the components field
let componentsIdent* {.compileTime.} = ident("components")

## The variable used to reference the initial size of any structs
let initialSizeIdent* {.compileTime.} = ident("initialSize")

## The variable for identifying the local world
let worldIdent* {.compileTime.} = ident("world")

## The method for deleting entities
let deleteProc* {.compileTime.} = ident("deleteEntity")