import componentDef, sequtils, macros, tupleDirective, archetypeBuilder

type
    WorldEnum*[T] = object
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
    ArchetypeEnum(ident: ident(prefix & "Archetypes"), values: archetypes.items.toSeq)

iterator items*[T](worldEnum: WorldEnum[T]): T =
    ## Iterates over all elements in a component set
    for component in worldEnum.values:
        yield component

proc codeGen*[T](worldEnum: WorldEnum[T]): NimNode =
    ## Creates code for representing this enum
    var entryList = worldEnum.values.mapIt(it.name.ident).deduplicate
    if entryList.len == 0:
        entryList.add ident("Dummy")
    result = newEnum(worldEnum.ident, entryList, public = false, pure = true)
