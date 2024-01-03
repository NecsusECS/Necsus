import entityId, archetypeStore, options

type
    QueryItem*[Comps: tuple] = tuple[entityId: EntityId, components: Comps]
        ## An individual value yielded by a query. Where `Comps` is a tuple of the components to fetch in
        ## this query

    Query*[Comps: tuple] = ref object
        ## Allows systems to query for entities with specific components. Where `Comps` is a tuple of
        ## the components to fetch in this query.
        archetypes: seq[ArchView[Comps]]

    Not*[Comps] = distinct int8
        ## A query flag that indicates a component should be excluded from a query. Where `Comps` is
        ## the single component that should be excluded.

proc newQuery*[Comps: tuple](archetypes: sink seq[ArchView[Comps]]): Query[Comps] =
    ## Creates a new object for executing a query
    Query[Comps](archetypes: archetypes)

iterator pairs*[Comps: tuple](query: Query[Comps]): QueryItem[Comps] {.inline.} =
    ## Iterates through the entities in a query
    var slot: Comps
    for view in query.archetypes.items:
        for entityId in view.items(slot):
            yield (entityId, slot)

iterator items*[Comps: tuple](query: Query[Comps]): Comps {.inline.} =
    ## Iterates through the entities in a query
    for (_, components) in query.pairs: yield components

proc len*[Comps: tuple](query: Query[Comps]): uint =
    ## Returns the number of entities in this query
    for arch in query.archetypes: result += arch.len

proc single*[Comps: tuple](query: Query[Comps]): Option[Comps] =
    ## Returns a single element from a query
    for comps in query:
        return some(comps)
