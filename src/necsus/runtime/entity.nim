import intsets

type
    EntityId* = distinct int
        ## Identity of an entity

    EntityMetadata*[C: enum] = object
        ## General data about an entity
        components*: set[C]

    EntitySet* = ref object
        ## A set of entity IDs
        entities: IntSet

proc `[]`*[T](s: openarray[T], id: EntityId): T =
    ## Allows indexing into an openarray by directly using an entity id
    s[int(id)]

proc `$`*(entityId: EntityId): string =
    ## Stringify an EntityId
    "EntityId(" & $int(entityId) & ")"

iterator items*(entities: EntitySet): EntityId =
    ## Produces all entities in this set
    for id in IntSet(entities.entities):
        yield EntityId(id)

proc newEntitySet*(): EntitySet =
    ## Create a new entity set
    EntitySet(entities: initIntSet())

proc `+=`*(entities: var EntitySet, entityId: EntityId) =
    ## Create a new entity set
    incl(IntSet(entities.entities), int(entityId))