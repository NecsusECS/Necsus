import entity

type
    QueryFilterKind = enum All, Matching
        ## The various kinds of filters that can be set

    QueryFilter*[C: enum] {.shallow.} = object
        ## Defines the rules for including an entity in a component
        case kind: QueryFilterKind
        of All:
            discard
        of Matching:
            components: set[C]

    Query*[T: tuple] = concept q
        ## Allows systems to query for entities with specific components
        for entity in q:
            entity is T

    RealQuery*[C: enum, T: tuple] = object
        filter: QueryFilter[C]
        entities: EntitySet
        create: proc (entityId: EntityId): T

iterator items*[C: enum, T: tuple](query: RealQuery[C, T]): T =
    ## Iterates through the entities in a query
    for entityId in items(query.entities):
        yield query.create(EntityId(entityId))

proc newQuery*[C: enum, T: tuple](
    entities: EntitySet,
    create: proc (entityId: EntityId): T
): RealQuery[C, T] =
    ## Creates a new query instance
    RealQuery[C, T](
        filter: QueryFilter[C](kind: QueryFilterKind.All),
        entities: entities,
        create: create
    )

