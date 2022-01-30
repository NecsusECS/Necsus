import macros, hashes, sequtils, strutils, nimNode

type
    ComponentDef* = distinct NimNode
        ## An individual component symbol within the ECS

proc `==`*(a, b: ComponentDef): bool =
    ## Compare two ComponentDef instances
    cmp(NimNode(a), NimNode(b)) == 0

proc `<`*(a, b: ComponentDef): auto = cmp(NimNode(a), NimNode(b)) < 0

proc `$`*(def: ComponentDef): string =
    ## Stringify a ComponentDef
    $(def.repr)

proc name*(def: ComponentDef): string =
    ## Returns the name of a component
    NimNode(def).symbols.join("_")

proc generateName*(components: openarray[ComponentDef]): string =
    ## Creates a name to describe the given components
    components.mapIt(it.name).join("_")

proc ident*(def: ComponentDef): NimNode =
    ## Stringify a ComponentDef
    result = copy(NimNode(def))
    result.copyLineInfo(NimNode(def))

proc hash*(def: ComponentDef): Hash = hash(NimNode(def))
