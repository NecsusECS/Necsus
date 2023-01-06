import entityId, archetypeStore

type
    QueryItem*[Comps: tuple] = tuple[entityId: EntityId, components: Comps]
        ## An individual value yielded by a query. Where `Comps` is a tuple of the components to fetch in
        ## this query

    Query*[Comps: tuple] = object
        ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
        ## the components to fetch in this query.
        archetypes: seq[ArchView[Comps]]

    Not*[Comps] = distinct int8
        ## A query flag that indicates a component should be excluded from a query. Where `Comps` is
        ## the single component that should be excluded.

proc newQuery*[Comps: tuple](archetypes: sink seq[ArchView[Comps]]): Query[Comps] =
    ## Creates a new object for executing a query
    result.archetypes = archetypes

iterator pairs*[Comps: tuple](query: Query[Comps]): QueryItem[Comps] {.inline.} =
    ## Iterates through the entities in a query
    for view in query.archetypes:
        for entityId, components in view:
            yield (entityId, components)

iterator items*[Comps: tuple](query: Query[Comps]): Comps {.inline.} =
    ## Iterates through the entities in a query
    for (_, components) in query.pairs: yield components
