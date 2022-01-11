import macros, hashes, sequtils, strutils

type
    ComponentDef* = distinct NimNode
        ## An individual component symbol within the ECS

proc `==`*(a, b: ComponentDef): auto =
    ## Compare two ComponentDef instances
    eqIdent(NimNode(a), NimNode(b))

proc `<`*(a, b: ComponentDef): auto =
    NimNode(a).strVal < NimNode(b).strVal

proc `$`*(def: ComponentDef): string =
    ## Stringify a ComponentDef
    $(NimNode(def))

proc name*(def: ComponentDef): string =
    ## Returns the name of a component
    NimNode(def).strVal

proc ident*(def: ComponentDef): NimNode =
    ## Stringify a ComponentDef
    ident(def.name)

proc hash*(def: ComponentDef): Hash = hash(def.name)

proc generateName*(components: openarray[ComponentDef]): string =
    ## Creates a name to describe the given components
    components.mapIt(it.name).join()
