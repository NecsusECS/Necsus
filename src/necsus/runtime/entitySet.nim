import intsets, entity

type

    EntitySet* = ref object
        ## A set of entity IDs
        entities: IntSet

iterator items*(entities: EntitySet): EntityId =
    ## Produces all entities in this set
    for id in entities.entities:
        yield EntityId(id)

proc newEntitySet*(): EntitySet =
    ## Create a new entity set
    EntitySet(entities: initIntSet())

proc `+=`*(entities: var EntitySet, entityId: EntityId) =
    ## Create a new entity set
    incl(entities.entities, int(entityId))

func contains*(entities: EntitySet, entityId: EntityId): bool =
    entities.entities.contains(int(entityId))

func `-=`*(entities: var EntitySet, toRemove: EntitySet) =
    ## Removes a set of entities from this instance
    entities.entities.excl(toRemove.entities)

func `-=`*(entities: var EntitySet, toRemove: EntityId) =
    ## Removes a set of entities from this instance
    entities.entities.excl(int(toRemove))

func `$`*(entities: EntitySet): string =
    ## Stringify
    $(entities.entities)

func clear*(entities: var EntitySet) =
    ## Removes all values
    entities.entities.clear
