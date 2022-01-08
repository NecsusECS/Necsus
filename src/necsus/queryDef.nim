import componentDef, tables, sequtils, strutils

type
    QueryDef* = object
        ## A single query definition
        components: seq[ComponentDef]

    QuerySet* = object
        ## All possible queries
        objSymbol: string
        queries: OrderedTable[QueryDef, string]

proc newQueryDef*(components: seq[ComponentDef]): QueryDef =
    QueryDef(components: components)

proc `==`*(a, b: QueryDef): auto =
    ## Compare two QueryDef instances
    a.components == b.components

iterator items*(query: QueryDef): ComponentDef =
    ## Produce all components in a query
    for component in query.components: yield component

proc rootName(query: QueryDef): string =
    query.components.mapIt(it.name).join()

proc newQuerySet*(prefix: string, queries: openarray[QueryDef]): QuerySet =
    ## Create a set of all queries in a set of systems
    result.objSymbol = prefix & "Queries"
    result.queries = initOrderedTable[QueryDef, string]()
    var suffixes = initTable[string, int]()
    for query in queries.toSeq.deduplicate:
        let name = query.rootName
        let suffix = suffixes.mgetOrPut(name, 0)
        suffixes[name] = suffix + 1
        result.queries[query] = name & $suffix

iterator items*(queries: QuerySet): tuple[name: string, query: QueryDef] =
    ## Produce all queries and their property names
    for (query, name) in queries.queries.pairs: yield (name, query)

proc objSymbol*(queries: QuerySet): string =
    ## Returns the name of this query set
    queries.objSymbol

