import componentDef, parse, algorithm, sequtils, macros

type
    ComponentSet* = object
        ## A group of components
        enumSymbol: NimNode
        components: seq[ComponentDef]

proc enumSymbol*(components: ComponentSet): auto = components.enumSymbol

proc uniqueComponents(app: ParsedApp, systems: openarray[ParsedSystem]): seq[ComponentDef] =
    ## Pulls any component definitions from an arg
    concat(app.components.toSeq, systems.components.toSeq).sorted.deduplicate

proc componentSet*(
    prefix: string,
    app: ParsedApp,
    systems: openarray[ParsedSystem]
): ComponentSet =
    ## Pulls all unique components from a set of parsed systems
    ComponentSet(
        enumSymbol: ident(prefix & "Components"),
        components: uniqueComponents(app, systems)
    )

iterator items*(components: ComponentSet): ComponentDef =
    ## Iterates over all components in a component set
    for component in components.components:
        yield component
