import componentDef, hashes, sequtils, macros

type
    DirectiveArgKind* = enum
        ## Indicates the behavior of a directive
        Include, Exclude, Optional

    DirectiveArg* = object
        ## Represents a single argument within a directive. For example, in:
        ## Query[(Foo, Bar, Baz)]
        ## This would just represent `Foo` or `Bar` or `Baz`
        component*: ComponentDef
        isPointer*: bool
        kind*: DirectiveArgKind

    TupleDirective* = object of RootObj
        ## Parent type for all tuple based directives
        args*: seq[DirectiveArg]

proc newDirectiveArg*(component: ComponentDef, isPointer: bool, kind: DirectiveArgKind): auto =
    ## Creates a DirectiveArg
    DirectiveArg(component: component, isPointer: isPointer, kind: kind)

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
    if def.isPointer: nnkPtrTy.newTree(NimNode(def.component)) else: NimNode(def.component)

iterator items*(directive: TupleDirective): ComponentDef =
    ## Produce all components in a directive
    for arg in directive.args: yield arg.component

proc comps*(directive: TupleDirective): seq[ComponentDef] =
    ## Produce all components in a directive
    directive.items.toSeq

iterator args*(directive: TupleDirective): DirectiveArg =
    ## Produce all args in a directive
    for arg in directive.args: yield arg

proc generateName*(directive: TupleDirective): string =
    ## Produces a readable name describing this directive
    directive.items.toSeq.generateName

proc name*(directive: TupleDirective): string =
    ## Produces a readable name describing this directive
    directive.generateName

proc hash*(directive: TupleDirective): Hash = hash(directive.args)

proc indexOf*(directive: TupleDirective, comp: ComponentDef): int =
    ## Returns the index of a component in this directive
    for i, arg in directive.args:
        if arg.component == comp:
            return i
    raise newException(KeyError, "Could not find component: " & $comp)

proc contains*(directive: TupleDirective, comp: ComponentDef): bool =
    ## Returns the index of a component in this directive
    for i, arg in directive.args:
        if arg.component == comp:
            return true
    return false

template createDirective(typ: untyped) =

    type
        typ* = object of TupleDirective
            ## A single directive definition

    proc `new typ`*(args: seq[DirectiveArg]): typ =
        typ(args: args)

    proc `==`*(a, b: typ): auto =
        ## Compare two Directive instances
        a.args == b.args

    proc `<`*(a, b: typ): auto =
        ## Compare two Directive instances
        if a.args.len < b.args.len:
            return true
        for i in 0..<b.args.len:
            if a.args[i] < b.args[i]:
                return true
            elif a.args[i] != b.args[i]:
                return false
        return false

createDirective(QueryDef)
createDirective(SpawnDef)
createDirective(AttachDef)
createDirective(DetachDef)
createDirective(LookupDef)
