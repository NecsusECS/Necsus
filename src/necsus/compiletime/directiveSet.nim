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

proc directives*[T](directives: DirectiveSet[T]): seq[T] =
    ## Produce all directives
    directives.values.keys.toSeq

iterator items*[T](directives: DirectiveSet[T]): tuple[name: string, value: T] =
    ## Produce all directives and their property names
    for (value, name) in directives.values.pairs: yield (name, value)

proc symbol*[T](directives: DirectiveSet[T]): string =
    ## Returns the name of this query set
    directives.symbol

proc containing*(queries: DirectiveSet[QueryDef], components: openarray[ComponentDef]): seq[QueryDef] =
    ## Yields all queries that reference the given components
    let compSet = components.toHashSet
    for query in queries.values.keys:
        if query.toSeq.allIt(it in compSet):
            result.add(query)

proc mentioning*(queries: DirectiveSet[QueryDef], components: openarray[ComponentDef]): seq[QueryDef] =
    ## Yields all queries that mention the given component
    let compSet = components.toHashSet
    for query in queries.values.keys:
        if query.toSeq.anyIt(it in compSet):
            result.add(query)

proc nameOf*[T](directives: DirectiveSet[T], value: T): string =
    ## Returns the name of a directive
    directives.values[value]
