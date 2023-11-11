import macros, hashes, sequtils, strutils, nimNode

type
    ComponentDef* = object
        ## An individual component symbol within the ECS
        node*: NimNode
        name*: string
        cachedHash: Hash

proc newComponentDef*(node: NimNode): ComponentDef =
    ## Instantiate a ComponentDef
    result.node = node
    result.name = node.symbols.join("_")
    result.cachedHash = hash(node)

proc `==`*(a, b: ComponentDef): bool =
    ## Compare two ComponentDef instances
    cmp(a.node, b.node) == 0

proc `<`*(a, b: ComponentDef): auto = cmp(a.node, b.node) < 0

proc `$`*(def: ComponentDef): string =
    ## Stringify a ComponentDef
    $(def.node.repr)

proc generateName*(components: openarray[ComponentDef]): string =
    ## Creates a name to describe the given components
    components.mapIt(it.name).join("_")

proc ident*(def: ComponentDef): NimNode =
    ## Stringify a ComponentDef
    result = copy(def.node)
    result.copyLineInfo(def.node)

proc hash*(def: ComponentDef): Hash = def.cachedHash
