import componentDef

type
    QueryDef* = object
        components: seq[ComponentDef]

proc newQueryDef*(components: seq[ComponentDef]): QueryDef =
    QueryDef(components: components)

iterator items*(query: QueryDef): ComponentDef =
    for component in query.components:
        yield component

