type
    QueryFilterKind {.pure.} = enum All, Matching, Excluding, Both
        ## The various kinds of filters that can be set

    QueryFilter*[C: enum] {.shallow.} = ref object
        ## Defines the rules for including an entity in a component
        case kind: QueryFilterKind
        of All:
            discard
        of Matching, Excluding:
            components: set[C]
        of Both:
            first, second: QueryFilter[C]

func filterAll*[C: enum](): auto =
    ## Creates a filter that matches all components
    QueryFilter[C](kind: QueryFilterKind.All)

func filterMatching*[C: enum](components: set[C]): auto =
    ## Creates a filter that must match the given components
    QueryFilter[C](kind: QueryFilterKind.Matching, components: components)

func filterExcluding*[C: enum](components: set[C]): auto =
    ## Creates a filter that must not include any of the given components
    QueryFilter[C](kind: QueryFilterKind.Excluding, components: components)

func filterBoth*[C: enum](first, second: QueryFilter[C]): auto =
    ## Creates a filter that requires two other filters both match
    QueryFilter[C](kind: QueryFilterKind.Both, first: first, second: second)

func evaluate*[C](filter: QueryFilter[C], components: set[C]): bool =
    ## Evaluates whether a set of components matches a query filter
    case filter.kind
    of QueryFilterKind.All: true
    of QueryFilterKind.Matching: components >= filter.components
    of QueryFilterKind.Excluding: (components * filter.components).card == 0
    of QueryFilterKind.Both: filter.first.evaluate(components) and filter.second.evaluate(components)
