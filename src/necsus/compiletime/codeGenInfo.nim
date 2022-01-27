import macros, componentSet, parse, directiveSet, directive, sequtils, componentDef, localDef

type CodeGenInfo* = object
    ## Contains all the information needed to do high level code gen
    config*: NimNode
    systems*: seq[ParsedSystem]
    components*: ComponentSet
    queries*: DirectiveSet[QueryDef]
    spawns*: DirectiveSet[SpawnDef]
    attaches*: DirectiveSet[AttachDef]
    detaches*: DirectiveSet[DetachDef]
    locals*: DirectiveSet[LocalDef]

proc newCodeGenInfo*(name: NimNode, config: NimNode, allSystems: openarray[ParsedSystem]): CodeGenInfo =
    ## Collects data needed for code gen from all the parsed systems
    CodeGenInfo(
        config: config,
        systems: allSystems.toSeq,
        components: allSystems.componentSet(name.strVal),
        queries: newDirectiveSet[QueryDef](name.strVal, allSystems.queries.toSeq),
        spawns: newDirectiveSet[SpawnDef](name.strVal, allSystems.spawns.toSeq),
        attaches: newDirectiveSet[AttachDef](name.strVal, allSystems.attaches.toSeq),
        detaches: newDirectiveSet[DetachDef](name.strVal, allSystems.detaches.toSeq),
        locals: newDirectiveSet[LocalDef](name.strVal, allSystems.locals.toSeq),
    )

proc componentEnumVal*(components: ComponentSet, component: ComponentDef): NimNode =
    ## Creates a reference to a component enum value
    nnkDotExpr.newTree(components.enumSymbol, component.ident)

proc asTupleType*(args: openarray[DirectiveArg]): NimNode =
    ## Creates a tuple type from a list of components
    result = nnkTupleConstr.newTree()
    for arg in args:
        result.add(if arg.isPointer: nnkPtrTy.newTree(arg.component.ident) else: arg.component.ident)

proc createComponentSet*(codeGenInfo: CodeGenInfo, components: openarray[ComponentDef]): NimNode =
    ## Creates the tuple needed to store
    result = nnkCurly.newTree()
    for component in components:
        result.add(codeGenInfo.components.componentEnumVal(component))

## Returns the identity needed to access the components field
let componentsIdent* {.compileTime.} = ident("components")

## The variable used to reference the initial size of any structs
let confIdent* {.compileTime.} = ident("config")

## The variable for identifying the local world
let worldIdent* {.compileTime.} = ident("world")

## The method for deleting entities
let deleteProc* {.compileTime.} = ident("deleteEntity")
