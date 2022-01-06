import componentDef, parse, algorithm, sequtils, macros

type
    ComponentSet* = object
        ## A group of components
        symbol: NimNode
        components: seq[ComponentDef]

proc symbol*(components: ComponentSet): auto = components.symbol

proc uniqueComponents(systems: openarray[ParsedSystem]): seq[ComponentDef] =
    ## Pulls any component definitions from an arg
    toSeq(systems.components).sorted.deduplicate

proc componentSet*(
    systems: openarray[ParsedSystem],
    prefix: string
): ComponentSet =
    ## Pulls all unique components from a set of parsed systems
    ComponentSet(
        symbol: ident(prefix & "Components"),
        components: systems.uniqueComponents
    )

iterator items*(components: ComponentSet): ComponentDef =
    ## Iterates over all components in a component set
    for component in components.components:
        yield component
