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

    RealQuery*[T] = object
        entities: EntitySet
        create: proc (entityId: EntityId): T

iterator items*[T](query: RealQuery[T]): T =
    ## Iterates through the entities in a query
    for entityId in items(query.entities):
        yield query.create(EntityId(entityId))

proc newQuery*[T](entities: EntitySet, create: proc (
        entityId: EntityId): T): RealQuery[T] =
    ## Creates a new query instance
    RealQuery[T](entities: entities, create: create)

