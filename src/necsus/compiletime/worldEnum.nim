import componentDef, parse, algorithm, sequtils, macros, tupleDirective, directiveSet, archetypeBuilder

type
    WorldEnum*[T] = object
        ## A group of values represented as values in an enum
        enumSymbol: NimNode
        values: seq[T]

    ArchetypeEnum* = WorldEnum[Archetype[ComponentDef]]
        ## An enum describing the different archetypes in a world

    ComponentEnum* = WorldEnum[ComponentDef]
        ## An enum where every component in an app has a value

    QueryEnum* = WorldEnum[QueryDef]
        ## An enum where every query in an app has a value

proc enumSymbol*[T](worldEnum: WorldEnum[T]): auto = worldEnum.enumSymbol
    ## Returns the symbol used to reference an enum in code

proc archetypeEnum*(prefix: string, archetypes: ArchetypeSet[ComponentDef]): ArchetypeEnum =
    ## Creates a set of unique enums from the various archetypes
    ArchetypeEnum(enumSymbol: ident(prefix & "Archetypes"), values: archetypes.items.toSeq)

proc componentEnum*(prefix: string, app: ParsedApp, systems: openarray[ParsedSystem]): ComponentEnum =
    ## Pulls all unique components from a set of parsed systems
    let uniqueComponents = concat(app.components.toSeq, systems.components.toSeq).sorted.deduplicate
    return ComponentEnum(enumSymbol: ident(prefix & "Components"), values: uniqueComponents)

proc queryEnum*(prefix: string, queries: DirectiveSet[QueryDef]): QueryEnum =
    ## Pulls all unique components from a set of parsed systems
    return QueryEnum(enumSymbol: ident(prefix & "Queries"), values: queries.items.toSeq.mapIt(it.value))

iterator items*[T](worldEnum: WorldEnum[T]): T =
    ## Iterates over all elements in a component set
    for component in worldEnum.values:
        yield component

proc enumRef*[T](worldEnum: WorldEnum[T], value: T): NimNode =
    ## Creates a reference to a component enum value
    nnkDotExpr.newTree(worldEnum.enumSymbol, value.name.ident)

proc codeGen*[T](worldEnum: WorldEnum[T]): NimNode =
    ## Creates code for representing this enum
    var entryList = worldEnum.values.mapIt(it.name.ident).deduplicate
    if entryList.len == 0:
        entryList.add ident("Dummy")
    result = newEnum(worldEnum.enumSymbol, entryList, public = false, pure = true)
