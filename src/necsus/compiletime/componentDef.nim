import macros, hashes, sequtils, strutils, ../util/nimNode, tables

type
    ComponentDef* = ref object
        ## An individual component symbol within the ECS
        node*: NimNode
        name*: string
        cachedHash: Hash
        uniqueId*: uint16

var ids {.compileTime.}: uint16
var lookup {.compileTime.} = initTable[NimNode, uint16]()

proc getArchetypeValueId(value: NimNode): uint16 =
    if not lookup.hasKey(value):
        lookup[value] = ids
        ids += 1
    return lookup[value]

proc newComponentDef*(node: NimNode): ComponentDef =
    ## Instantiate a ComponentDef
    ComponentDef(node: node, name: node.symbols.join("_"), cachedHash: hash(node), uniqueId: getArchetypeValueId(node))

proc `==`*(a, b: ComponentDef): bool =
    ## Compare two ComponentDef instances
    a.uniqueId == b.uniqueId

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

proc addSignature*(onto: var string, comp: ComponentDef) = onto.addSignature(comp.node)
    ## Generate a unique ID for a component