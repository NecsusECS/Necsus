type
    QueryFilterKind {.pure.} = enum All, Matching
        ## The various kinds of filters that can be set

    QueryFilter*[C: enum] {.shallow.} = object
        ## Defines the rules for including an entity in a component
        case kind: QueryFilterKind
        of All:
            discard
        of Matching:
            components: set[C]

func filterAll*[C: enum](): auto =
    ## Creates a filter that matches all components
    QueryFilter[C](kind: QueryFilterKind.All)

func filterMatching*[C: enum](components: set[C]): auto =
    ## Creates a filter that must match the given components
    QueryFilter[C](kind: QueryFilterKind.Matching, components: components)

func evaluate*[C](filter: QueryFilter[C], components: set[C]): bool =
    ## Evaluates whether a set of components matches a query filter
    case filter.kind
    of QueryFilterKind.All: true
    of QueryFilterKind.Matching: components >= filter.components

