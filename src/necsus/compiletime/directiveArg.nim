import componentDef, hashes, macros, sequtils, strutils

type
    DirectiveArgKind* = enum
        ## Indicates the behavior of a directive
        Include, Exclude, Optional

    DirectiveArg* = ref object
        ## Represents a single argument within a directive. For example, in:
        ## `Query[(Foo, Bar, Baz)]`
        ## This would just represent `Foo` or `Bar` or `Baz`
        component*: ComponentDef
        isPointer*: bool
        kind*: DirectiveArgKind
        signatureCache: string

proc newDirectiveArg*(component: ComponentDef, isPointer: bool, kind: DirectiveArgKind): DirectiveArg =
    ## Creates a DirectiveArg
    return DirectiveArg(component: component, isPointer: isPointer, kind: kind)

proc `$`*(arg: DirectiveArg): string =
    result = $arg.kind & "("
    if arg.isPointer:
        result &= "ptr "
    result &= arg.component.readableName & ")"

proc `==`*(a, b: DirectiveArg): auto =
    ## Compare two Directive instances
    (a.isPointer == b.isPointer) and (a.component == b.component)

proc `<`*(a, b: DirectiveArg): auto =
    ## Allow deterministic sorting of directives
    (a.component < b.component) or (a.isPointer < b.isPointer) or (a.kind < b.kind)

proc hash*(arg: DirectiveArg): Hash = hash(arg.component)
    ## Generate a unique hash

proc type*(def: DirectiveArg): NimNode =
    ## The type of this component
    if def.isPointer: nnkPtrTy.newTree(def.component.node) else: def.component.node

proc name(arg: DirectiveArg): string =
    ## Creates a name to describe an arg
    if arg.isPointer:
        result = "p"
    case arg.kind
    of Include: result &= "i"
    of Exclude: result &= "e"
    of Optional: result &= "o"
    result &= arg.component.name

proc isAccessory*(arg: DirectiveArg): bool =
    ## Whether this arg contains an accessory component
    return arg.component.isAccessory

proc generateName*(args: openarray[DirectiveArg]): string =
    ## Creates a name to describe the given components
    args.toSeq.mapIt(it.name).join("_")

proc comps*(args: openarray[DirectiveArg]): seq[ComponentDef] =
    ## Returns all the components from a set of args
    for arg in args: result.add(arg.component)

proc addSignature*(onto: var string, arg: DirectiveArg) =
    ## Generate a unique ID for a component
    if arg.signatureCache == "":
        arg.signatureCache = $arg.kind
        if arg.isPointer:
            arg.signatureCache &= "p"
        arg.signatureCache.addSignature(arg.component)
    onto &= arg.signatureCache