import entityId

type
    QueryItem*[C: tuple] = tuple[entityId: EntityId, components: C]
        ## An individual value yielded by a query. Where `C` is a tuple of the components to fetch in
        ## this query

    Query*[C: tuple] = proc(): iterator(): QueryItem[C]
        ## Allows systems to query for entities with specific components. Where `C` is a tuple of
        ## the components to fetch in this query.

    Not*[C] = distinct int8
        ## A query flag that indicates a component should be excluded from a query. Where `C` is
        ## the single component that should be excluded.

iterator pairs*[C: tuple](query: Query[C]): QueryItem[C] =
    ## Iterates through the entities in a query
    let iter = query()
    for pair in iter(): yield pair

iterator items*[C: tuple](query: Query[C]): C =
    ## Iterates through the entities in a query
    for (_, components) in query.pairs: yield components
