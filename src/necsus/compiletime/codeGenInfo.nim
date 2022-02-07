import componentSet, parse, directiveSet, tupleDirective, monoDirective, componentDef, localDef
import macros, sequtils, options
import ../runtime/query

type CodeGenInfo* = object
    ## Contains all the information needed to do high level code gen
    config*: NimNode
    app*: ParsedApp
    systems*: seq[ParsedSystem]
    components*: ComponentSet
    queries*: DirectiveSet[QueryDef]
    spawns*: DirectiveSet[SpawnDef]
    attaches*: DirectiveSet[AttachDef]
    detaches*: DirectiveSet[DetachDef]
    locals*: DirectiveSet[LocalDef]
    shared*: DirectiveSet[SharedDef]
    lookups*: DirectiveSet[LookupDef]
    inboxes*: DirectiveSet[InboxDef]
    outboxes*: DirectiveSet[OutboxDef]

template directives[T](name: NimNode, app: ParsedApp, allSystems: openarray[ParsedSystem], extract: untyped): auto =
    ## Creates a directive set for a specific type of directive
    let fromSystems: seq[T] = allSystems.`extract`
    let fromApp: seq[T] = app.`extract`
    newDirectiveSet[T](name.strVal, concat(fromSystems, fromApp))

proc newCodeGenInfo*(name: NimNode, config: NimNode, app: ParsedApp, allSystems: openarray[ParsedSystem]): CodeGenInfo =
    ## Collects data needed for code gen from all the parsed systems
    CodeGenInfo(
        config: config,
        app: app,
        systems: allSystems.toSeq,
        components: componentSet(name.strVal, app, allSystems),
        queries: directives[QueryDef](name, app, allSystems, queries),
        spawns: directives[SpawnDef](name, app, allSystems, spawns),
        attaches: directives[AttachDef](name, app, allSystems, attaches),
        detaches: directives[DetachDef](name, app, allSystems, detaches),
        locals: directives[LocalDef](name, app, allSystems, locals),
        shared: directives[SharedDef](name, app, allSystems, shared),
        lookups: directives[LookupDef](name, app, allSystems, lookups),
        inboxes: directives[InboxDef](name, app, allSystems, inboxes),
        outboxes: directives[OutboxDef](name, app, allSystems, outboxes),
    )

proc componentEnumVal*(components: ComponentSet, component: ComponentDef): NimNode =
    ## Creates a reference to a component enum value
    nnkDotExpr.newTree(components.enumSymbol, component.name.ident)

proc asTupleType*(args: openarray[DirectiveArg]): NimNode =
    ## Creates a tuple type from a list of components
    result = nnkTupleConstr.newTree()
    for arg in args:
        let componentIdent = if arg.isPointer: nnkPtrTy.newTree(arg.component.ident) else: arg.component.ident
        case arg.kind
        of Include: result.add(componentIdent)
        of Exclude: result.add(nnkBracketExpr.newTree(bindSym("Not"), componentIdent))
        of Optional: result.add(nnkBracketExpr.newTree(bindSym("Option"), componentIdent))

proc createComponentSet*(codeGenInfo: CodeGenInfo, components: openarray[ComponentDef]): NimNode =
    ## Creates the tuple needed to store
    result = nnkCurly.newTree()
    for component in components:
        result.add(codeGenInfo.components.componentEnumVal(component))

proc componentStoreIdent*(component: ComponentDef): NimNode =
    ## Creates a variable for referencing a component
    ident("component_" & component.name)

## The variable used to reference the initial size of any structs
let confIdent* {.compileTime.} = ident("config")

## The variable for identifying the local world
let worldIdent* {.compileTime.} = ident("world")

## The method for deleting entities
let deleteProc* {.compileTime.} = ident("deleteEntity")
