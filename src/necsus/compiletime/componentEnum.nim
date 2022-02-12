import componentDef, parse, algorithm, sequtils, macros

type
    ComponentEnum* = object
        ## A group of components represented as values in an enum
        enumSymbol: NimNode
        components: seq[ComponentDef]

proc enumSymbol*(components: ComponentEnum): auto = components.enumSymbol

proc uniqueComponents(app: ParsedApp, systems: openarray[ParsedSystem]): seq[ComponentDef] =
    ## Pulls any component definitions from an arg
    concat(app.components.toSeq, systems.components.toSeq).sorted.deduplicate

proc componentEnum*(
    prefix: string,
    app: ParsedApp,
    systems: openarray[ParsedSystem]
): ComponentEnum =
    ## Pulls all unique components from a set of parsed systems
    ComponentEnum(
        enumSymbol: ident(prefix & "Components"),
        components: uniqueComponents(app, systems)
    )

iterator items*(components: ComponentEnum): ComponentDef =
    ## Iterates over all components in a component set
    for component in components.components:
        yield component
