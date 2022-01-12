import tables, componentDef, directive, sequtils, strutils, sets

type
    DirectiveSet*[T] = object
        ## All possible directives
        symbol: string
        values: OrderedTable[T, string]

proc newDirectiveSet*[T](prefix: string, values: openarray[T]): DirectiveSet[T] =
    ## Create a set of all directives in a set of systems
    result.symbol = prefix & $T

    result.values = initOrderedTable[T, string]()
    var suffixes = initTable[string, int]()

    for value in values.toSeq.deduplicate:
        let name = toLowerAscii($T) & value.toSeq.generateName
        let suffix = suffixes.mgetOrPut(name, 0)
        suffixes[name] = suffix + 1
        result.values[value] = name & $suffix

iterator items*[T](directives: DirectiveSet[T]): tuple[name: string, value: T] =
    ## Produce all directives and their property names
    for (value, name) in directives.values.pairs: yield (name, value)

proc symbol*[T](directives: DirectiveSet[T]): string =
    ## Returns the name of this query set
    directives.symbol

iterator containing*(
    queries: DirectiveSet[QueryDef],
    components: openarray[ComponentDef]
): tuple[name: string, value: QueryDef] =
    ## Yields all queries that reference the given components
    let compSet = components.toHashSet
    for (query, name) in queries.values.pairs:
        if query.toSeq.allIt(it in compSet):
            yield (name: name, value: query)

proc nameOf*[T](directives: DirectiveSet[T], value: T): string =
    ## Returns the name of a directive
    directives.values[value]
