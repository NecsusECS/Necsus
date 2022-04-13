import componentDef, parse, algorithm, sequtils, macros

type
    WorldEnum*[T] = object
        ## A group of values represented as values in an enum
        enumSymbol: NimNode
        values: seq[T]

    ComponentEnum* = WorldEnum[ComponentDef]

proc enumSymbol*[T](worldEnum: WorldEnum[T]): auto = worldEnum.enumSymbol

proc componentEnum*(prefix: string, app: ParsedApp, systems: openarray[ParsedSystem]): ComponentEnum =
    ## Pulls all unique components from a set of parsed systems
    let uniqueComponents = concat(app.components.toSeq, systems.components.toSeq).sorted.deduplicate
    return ComponentEnum(enumSymbol: ident(prefix & "Components"), values: uniqueComponents)

iterator items*[T](worldEnum: WorldEnum[T]): T =
    ## Iterates over all elements in a component set
    for component in worldEnum.values:
        yield component

proc enumRef*[T](worldEnum: WorldEnum[T], value: T): NimNode =
    ## Creates a reference to a component enum value
    nnkDotExpr.newTree(worldEnum.enumSymbol, value.name.ident)

proc createComponentEnum*(components: ComponentEnum): NimNode =
    ## Creates an enum with an item for every available component
    var componentList = toSeq(components).mapIt(it.name.ident)
    if componentList.len == 0:
        componentList.add ident("Dummy")
    result = newEnum(components.enumSymbol, componentList, public = false, pure = true)

proc codeGen*[T](worldEnum: WorldEnum[T]): NimNode =
    ## Creates code for representing this enum
    var entryList = worldEnum.values.mapIt(it.name.ident)
    if entryList.len == 0:
        entryList.add ident("Dummy")
    result = newEnum(worldEnum.enumSymbol, entryList, public = false, pure = true)
