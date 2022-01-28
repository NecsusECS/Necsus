import componentDef, parse, algorithm, sequtils, macros

type
    ComponentSet* = object
        ## A group of components
        enumSymbol: NimNode
        components: seq[ComponentDef]

proc enumSymbol*(components: ComponentSet): auto = components.enumSymbol

proc uniqueComponents(systems: openarray[ParsedSystem]): seq[ComponentDef] =
    ## Pulls any component definitions from an arg
    toSeq(systems.components).sorted.deduplicate

proc componentSet*(
    systems: openarray[ParsedSystem],
    prefix: string
): ComponentSet =
    ## Pulls all unique components from a set of parsed systems
    ComponentSet(
        enumSymbol: ident(prefix & "Components"),
        components: systems.uniqueComponents
    )

iterator items*(components: ComponentSet): ComponentDef =
    ## Iterates over all components in a component set
    for component in components.components:
        yield component
