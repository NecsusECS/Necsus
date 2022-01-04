import entity

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

    Query*[T: tuple] = concept q
        ## Allows systems to query for entities with specific components
        for entity in q:
            entity is T

    QueryMembers*[C: enum] = object
        ## Contains membership information about a query
        filter: QueryFilter[C]
        entities: EntitySet

    RealQuery*[C: enum, T: tuple] = object
        members: ptr QueryMembers[C]
        create: proc (entityId: EntityId): T

iterator items*[C: enum, T: tuple](query: RealQuery[C, T]): T =
    ## Iterates through the entities in a query
    for entityId in items(query.members.entities):
        yield query.create(EntityId(entityId))

func newQuery*[C: enum, T: tuple](
    members: ptr QueryMembers[C],
    create: proc (entityId: EntityId): T
): RealQuery[C, T] =
    ## Creates a new query instance
    RealQuery[C, T](members: members, create: create)

func newQueryMembers*[C: enum](filter: sink QueryFilter[C]): QueryMembers[C] =
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


