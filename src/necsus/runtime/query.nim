import entityId

type
    QueryItem*[T: tuple] = tuple[entityId: EntityId, components: T]
        ## An individual value yielded by a query

    Query*[T: tuple] = proc(): iterator(): QueryItem[T]
        ## Allows systems to query for entities with specific components

    Not*[T] = distinct int8
        ## A query flag that indicates a component should be excluded from a query

iterator pairs*[T: tuple](query: Query[T]): QueryItem[T] =
    ## Iterates through the entities in a query
    let iter = query()
    for pair in iter(): yield pair

iterator items*[T: tuple](query: Query[T]): T =
    ## Iterates through the entities in a query
    for (_, components) in query.pairs: yield components
