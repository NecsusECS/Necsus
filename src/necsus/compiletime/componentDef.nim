import std/[macros, hashes, sequtils, strutils, macrocache]
import ../util/nimNode

type
    ComponentDef* = ref object
        ## An individual component symbol within the ECS
        node*: NimNode
        name*: string
        cachedHash: Hash
        uniqueId*: uint16

const ids = CacheCounter("NecsusComponentIds")

when NimMajor >= 2:
    const lookup = CacheTable("NecsusComponentIdCache")
else:
    import std/tables
    var lookup {.compileTime.} = initTable[string, NimNode]()

proc getArchetypeValueId(value: NimNode): uint16 =
    var sig: string
    sig.addSignature(value)

    if sig notin lookup:
        lookup[sig] = ids.value.newLit
        ids.inc

    return lookup[sig].intVal.uint16

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