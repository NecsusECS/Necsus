import entitySet, entity

type
    QueryFilterKind {.pure.} = enum All, Matching
        ## The various kinds of filters that can be set

    QueryFilter*[C: enum] {.shallow.} = object
        ## Defines the rules for including an entity in a component
        case kind: QueryFilterKind
        of All:
            discard
        of Matching:
            components: set[C]

    Query*[T: tuple] {.byref.} = object
        ## Allows systems to query for entities with specific components
        entities: EntitySet
        deleted: EntitySet
        create: proc (entityId: EntityId): T

    QueryMembers*[C: enum] = object
        ## Contains membership information about a query
        filter: QueryFilter[C]
        entities: EntitySet

iterator items*[T: tuple](query: Query[T]): T =
    ## Iterates through the entities in a query
    for (_, components) in query.pairs:
        yield components

iterator pairs*[T: tuple](query: Query[T]): tuple[entityId: EntityId, components: T] =
    ## Iterates through the entities in a query and their components
    for entityId in query.entities.items:
        if entityId notin query.deleted:
            yield (entityId, query.create(entityId))

func newQuery*[C: enum, T: tuple](
    members: QueryMembers[C],
    deleted: EntitySet,
    create: proc (entityId: EntityId): T
): Query[T] =
    ## Creates a new query instance
    Query[T](entities: members.entities, deleted: deleted, create: create)

func newQueryMembers*[C: enum](filter: QueryFilter[C]): QueryMembers[C] =
    ## Creates a new query member instance
    QueryMembers[C](filter: filter, entities: newEntitySet())

func evaluate*[C](members: QueryMembers[C], components: set[C]): bool =
    ## Evaluates whether a set of components matches a query filter
    case members.filter.kind
    of QueryFilterKind.All:
        true
    of QueryFilterKind.Matching:
        card(members.filter.components - components) == 0

proc `+=`*[C: enum](members: var QueryMembers[C], entityId: EntityId) =
    ## Adds an entity to a query membership
    members.entities += entityId

func filterMatching*[C: enum](components: set[C]): auto =
    QueryFilter[C](kind: QueryFilterKind.Matching, components: components)

proc finalizeDeletes*[T](query: var Query[T]) =
    ## Removes any entities that are pending deletion from this query
    query.entities -= query.deleted


