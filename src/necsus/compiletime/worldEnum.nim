import std/[macros, sequtils, sets]
import componentDef, tupleDirective, archetypeBuilder

type
    WorldEnum*[T] = ref object
        ## A group of values represented as values in an enum
        ident: NimNode
        values: seq[T]

    ArchetypeEnum* = WorldEnum[Archetype[ComponentDef]]
        ## An enum describing the different archetypes in a world

proc ident*[T](worldEnum: WorldEnum[T]): auto = worldEnum.ident
    ## Returns the symbol used to reference an enum in code

proc ident*[T](worldEnum: WorldEnum[T], value: T): NimNode =
    ## Creates a reference to a component enum value
    nnkDotExpr.newTree(worldEnum.ident, value.name.ident)

proc archetypeEnum*(prefix: string, archetypes: ArchetypeSet[ComponentDef]): ArchetypeEnum =
    ## Creates a set of unique enums from the various archetypes
    result.new
    result.ident = ident(prefix & "Archetypes")
    result.values = archetypes.items.toSeq

iterator items*[T](worldEnum: WorldEnum[T]): T =
    ## Iterates over all elements in a component set
    for component in worldEnum.values:
        yield component

iterator enumIdents*[T](worldEnum: WorldEnum[T]): NimNode =
    ## Returns all the idents present in a world enum
    if worldEnum.values.len == 0:
        yield ident("Dummy")
    else:
        var seen = initHashSet[T](worldEnum.values.len)
        for entry in worldEnum.values:
            if entry notin seen:
                yield entry.name.ident

proc codeGen*[T](worldEnum: WorldEnum[T]): NimNode =
    ## Creates code for representing this enum
    result = newEnum(worldEnum.ident, worldEnum.enumIdents.toSeq, public = false, pure = true)
