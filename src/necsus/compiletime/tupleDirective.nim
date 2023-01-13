import componentDef, hashes, sequtils

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

template createDirective(typ: untyped) =

    type
        typ* = object
            ## A single directive definition
            args*: seq[DirectiveArg]

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

    iterator items*(directive: typ): ComponentDef =
        ## Produce all components in a directive
        for arg in directive.args: yield arg.component

    iterator args*(directive: typ): DirectiveArg =
        ## Produce all args in a directive
        for arg in directive.args: yield arg

    proc generateName*(directive: typ): string =
        ## Produces a readable name describing this directive
        directive.items.toSeq.generateName

    proc name*(directive: typ): string =
        ## Produces a readable name describing this directive
        directive.generateName

    proc hash*(directive: typ): Hash = hash(directive.args)

    proc indexOf*(directive: typ, comp: ComponentDef): int =
        ## Returns the index of a component in this directive
        for i, arg in directive.args:
            if arg.component == comp:
                return i
        raise newException(KeyError, "Could not find component: " & $comp)

    proc contains*(directive: typ, comp: ComponentDef): bool =
        ## Returns the index of a component in this directive
        for i, arg in directive.args:
            if arg.component == comp:
                return true
        return false

createDirective(QueryDef)
createDirective(SpawnDef)
createDirective(AttachDef)
createDirective(DetachDef)
createDirective(LookupDef)
