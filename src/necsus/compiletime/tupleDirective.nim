import componentDef, hashes, sequtils, macros, strutils, ../util/bits, directiveArg

type
    TupleDirective* = ref object
        ## A directive that contains a single tuple
        args*: seq[DirectiveArg]
        name*: string
        filter: BitsFilter

proc newTupleDir*(args: openarray[DirectiveArg]): TupleDirective =
    ## Create a TupleDirective
    return TupleDirective(args: args.toSeq, name: args.items.toSeq.mapIt(it.component).generateName)

proc `$`*(dir: TupleDirective): string =
    dir.name & "(" & join(dir.args, ", ") & ")"

iterator items*(directive: TupleDirective): ComponentDef =
    ## Produce all components in a directive
    for arg in directive.args: yield arg.component

proc comps*(directive: TupleDirective): seq[ComponentDef] =
    ## Produce all components in a directive
    directive.items.toSeq

iterator args*(directive: TupleDirective): DirectiveArg =
    ## Produce all args in a directive
    for arg in directive.args: yield arg

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

proc `==`*(a, b: TupleDirective): auto =
    ## Compare two Directive instances
    a.args == b.args

proc `<`*(a, b: TupleDirective): auto =
    ## Compare two Directive instances
    if a.args.len < b.args.len:
        return true
    for i in 0..<b.args.len:
        if a.args[i] < b.args[i]:
            return true
        elif a.args[i] != b.args[i]:
            return false
    return false

proc filter*(dir: TupleDirective): BitsFilter =
    ## Returns the filter for a tuple
    if dir.filter == nil:
        var required = Bits()
        var excluded = Bits()
        for arg in dir.args:
            case arg.kind
            of DirectiveArgKind.Include: required.incl(arg.component.uniqueId)
            of DirectiveArgKind.Exclude: excluded.incl(arg.component.uniqueId)
            of DirectiveArgKind.Optional: discard
        dir.filter = newFilter(required, excluded)
    return dir.filter