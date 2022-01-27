import componentDef, hashes, sequtils

type
    DirectiveArg* = object
        ## Represents a single argument within a directive. For example, in:
        ## Query[(Foo, Bar, Baz)]
        ## This would _just_ represent `Foo` or `Bar` or `Baz`
        component*: ComponentDef
        isPointer*: bool

proc newDirectiveArg*(component: ComponentDef, isPointer: bool): auto =
    ## Creates a DirectiveArg
    DirectiveArg(component: component, isPointer: isPointer)

proc `==`*(a, b: DirectiveArg): auto =
    ## Compare two Directive instances
    (a.isPointer == b.isPointer) and (a.component == b.component)

proc hash*(arg: DirectiveArg): Hash = hash(arg.component)
    ## Generate a unique hash

template createDirective(typ: untyped) =

    type
        typ* = object
            ## A single directive definition
            args: seq[DirectiveArg]

    proc `new typ`*(args: seq[DirectiveArg]): typ =
        typ(args: args)

    proc `==`*(a, b: typ): auto =
        ## Compare two Directive instances
        a.args == b.args

    iterator items*(directive: typ): ComponentDef =
        ## Produce all components in a directive
        for arg in directive.args: yield arg.component

    iterator args*(directive: typ): DirectiveArg =
        ## Produce all args in a directive
        for arg in directive.args: yield arg

    proc generateName*(directive: typ): string =
        ## Produces a readable name describing this directive
        directive.items.toSeq.generateName

    proc hash*(directive: typ): Hash = hash(directive.args)

createDirective(QueryDef)
createDirective(SpawnDef)
createDirective(AttachDef)
createDirective(DetachDef)
