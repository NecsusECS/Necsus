import componentDef, hashes

template createDirective(typ: untyped) =

    type
        typ* = object
            ## A single directive definition
            components: seq[ComponentDef]

    proc `new typ`*(components: seq[ComponentDef]): typ =
        typ(components: components)

    proc `==`*(a, b: typ): auto =
        ## Compare two Directive instances
        a.components == b.components

    iterator items*(directive: typ): ComponentDef =
        ## Produce all components in a directive
        for component in directive.components: yield component

    proc hash*(directive: typ): Hash = hash(directive.components)

createDirective(QueryDef)
createDirective(SpawnDef)

