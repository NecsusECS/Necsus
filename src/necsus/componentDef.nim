import macros

type
    ComponentDef* = distinct NimNode
        ## An individual component symbol within the ECS

    ComponentSet* = seq[ComponentDef]
        ## A group of components

proc `==`*(a, b: ComponentDef): auto =
    ## Compare two ComponentDef instances
    eqIdent(NimNode(a), NimNode(b))

proc `<`*(a, b: ComponentDef): auto =
    NimNode(a).strVal < NimNode(b).strVal

proc `$`*(def: ComponentDef): string =
    ## Stringify a ComponentDef
    $(NimNode(def))

proc ident*(def: ComponentDef): NimNode =
    ## Stringify a ComponentDef
    ident(NimNode(def).strVal)

