import std/[macros, hashes, sequtils, strutils, macrocache, options, strformat]
import ../util/[nimNode, typeReader], ../runtime/pragmas

type ComponentDef* = ref object ## An individual component symbol within the ECS
  node*: NimNode
  name*: string
  uniqueId*: uint16
  isAccessory*: bool

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
  let id = getArchetypeValueId(node)
  ComponentDef(
    node: node,
    name: "c" & $id,
    uniqueId: id,
    isAccessory: node.hasPragma(bindSym("accessory")),
  )

proc readableName*(comp: ComponentDef): string =
  ## Returns a human readable name for a node
  comp.node.symbols.join("_")

proc `==`*(a, b: ComponentDef): bool =
  ## Compare two ComponentDef instances
  a.uniqueId == b.uniqueId

proc `<`*(a, b: ComponentDef): auto =
  cmp(a.node, b.node) < 0

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

proc hash*(def: ComponentDef): Hash =
  def.uniqueId.hash

proc addSignature*(onto: var string, comp: ComponentDef) =
  ## Generate a unique ID for a component
  onto &= comp.name

when NimMajor >= 2:
  const capacityCache = CacheTable("NecsusCapacityCache")
else:
  var capacityCache {.compileTime.} = initTable[string, NimNode]()

proc getCapacity(node: NimNode): Option[NimNode] =
  case node.kind
  of nnkSym:
    let hash = node.signatureHash
    if hash in capacityCache:
      let cached = capacityCache[hash]
      return
        if cached.kind == nnkEmpty:
          none(NimNode)
        else:
          some(cached)

    var res = node.getImpl.getCapacity()
    if res.isNone:
      let dealiased = node.resolveAlias()
      if dealiased.isSome:
        res = dealiased.get.getCapacity()

    capacityCache[hash] =
      if res.isSome:
        res.get
      else:
        newEmptyNode()

    return res
  of nnkObjectTy, nnkTypeDef:
    for pragma in node.findPragma:
      if pragma.isPragma(bindSym("maxCapacity")):
        return some(pragma[1])
  of nnkBracketExpr:
    return node[0].getCapacity
  else:
    return none(NimNode)

proc maxCapacity*(errorSite: NimNode, components: auto): Option[NimNode] =
  ## Calculates the storage size required to store a list of components
  for comp in components:
    assert(comp is ComponentDef)
    let capacity = comp.node.getCapacity
    if capacity.isSome:
      let newValue = newCall("uint", capacity.get)
      if result.isSome:
        result = some(newCall(bindSym("max"), result.get, newValue))
      else:
        result = some(newValue)

  when defined(requireMaxCapacity):
    if result.isNone:
      for comp in components:
        hint(fmt"{comp} does not have a maxCapacity pragma", comp.node)
      error(
        fmt"Must have at least one component with a maxCapacity defined: {components}",
        errorSite,
      )
