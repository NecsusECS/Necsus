import componentDef

type
    QueryDef* = object
        ## A single query definition
        components: seq[ComponentDef]

proc newQueryDef*(components: seq[ComponentDef]): QueryDef =
    QueryDef(components: components)

proc `==`*(a, b: QueryDef): auto =
    ## Compare two QueryDef instances
    a.components == b.components

iterator items*(query: QueryDef): ComponentDef =
    ## Produce all components in a query
    for component in query.components: yield component

