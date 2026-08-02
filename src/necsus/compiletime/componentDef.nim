import std/[macros, hashes, sequtils, strutils, macrocache, options, strformat]
import ../util/[nimNode, typeReader], ../runtime/pragmas

type ComponentDef* = ref object ## An individual component symbol within the ECS
  node*: NimNode
  name*: string
  uniqueId*: uint16
  presenceId*: uint16
    ## The column recording whether each entity in an archetype actually has this
    ## accessory. Only meaningful when `isAccessory`
  isAccessory*: bool

const ids = CacheCounter("NecsusComponentIds")

when NimMajor >= 2:
  const lookup = CacheTable("NecsusComponentIdCache")
  const presenceLookup = CacheTable("NecsusAccessoryPresenceIds")
else:
  import std/tables
  var lookup {.compileTime.} = initTable[string, NimNode]()
  var presenceLookup {.compileTime.} = initTable[string, NimNode]()

proc nextId(): NimNode =
  ## Hands out the next global column id
  result = ids.value.newLit
  ids.inc

proc getArchetypeValueId(sig: string): uint16 =
  if sig notin lookup:
    lookup[sig] = nextId()
  return lookup[sig].intVal.uint16

proc getPresenceId(sig: string): uint16 =
  ## The id of the column that records which entities have an accessory.
  ##
  ## This comes out of the same pool the components themselves are numbered from, which is
  ## what keeps a presence column an ordinary column: it needs no special case in the store
  ## and it is laid out and reached exactly like the value it stands for
  if sig notin presenceLookup:
    presenceLookup[sig] = nextId()
  return presenceLookup[sig].intVal.uint16

proc componentIdCount*(): int =
  ## The number of component ids handed out so far.
  ids.value

proc newComponentDef*(node: NimNode): ComponentDef =
  ## Instantiate a ComponentDef
  var sig: string
  sig.addSignature(node)

  let id = getArchetypeValueId(sig)
  let isAccessory = node.hasPragma(bindSym("accessory"))
  ComponentDef(
    node: node,
    name: "c" & $id,
    uniqueId: id,
    isAccessory: isAccessory,
    presenceId:
      if isAccessory:
        getPresenceId(sig)
      else:
        0,
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

proc columnId*(def: ComponentDef): NimNode =
  ## The literal this component is indexed by at runtime. Ids are global, so the same
  ## literal reaches this component's column in every archetype that has one
  newLit(def.uniqueId)

proc presenceColumnId*(def: ComponentDef): NimNode =
  ## The literal naming the column that says which entities have this accessory
  assert(def.isAccessory, "Only an accessory has a presence column")
  newLit(def.presenceId)

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
      let newValue = newCall("Natural", capacity.get)
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
