import archetype, algorithm, ../util/[bits, openAddr], hashes

export archetype, bits.hash, bits.`$`, bits.`==`

type
  BuilderAction = ref object
    ## A single way of moving from one archetype to another.
    ##
    ## A part is nil when there is no work in it: a filter that lets everything through,
    ## or an empty set of components, both describe a move that hands `source` straight
    ## back. Folding that down as the action is built means the graph walk tests for nil
    ## rather than re-deriving emptiness from the bitsets on every pass
    filter: BitsFilter
    attach, detach, optDetach: Bits
    bothDetach: Bits
      ## `detach` and `optDetach` together, so an action that does both still only takes
      ## a single pass to apply
    attachCore, attachInert: Bits
      ## `attach` split across the two halves of a walk state. Filled in once the inert
      ## accessories are known, which is not until every action has been declared

  ActionIndex = object
    ## Actions arranged so that a single archetype only has to look at the ones that
    ## stand a chance of applying to it.
    ##
    ## An action whose filter requires a component can never fire against an archetype
    ## missing it, so each such action is filed under one of the components it requires.
    ## Walking an archetype's own components then reaches every candidate, and never
    ## looks at the rest. On a large app this is the difference between evaluating every
    ## action against every archetype and evaluating a small fraction of them
    entries: seq[BuilderAction]
      ## Ungated actions first, then the gated ones grouped by the component gating them
    ungated: int
      ## How many leading entries are ungated
    gateStart: seq[int]
      ## Where each component's group starts in `entries`
    gateEnd: seq[int]
      ## Where each component's group ends. Equal to `gateStart` when nothing is gated
      ## on that component

  ArchetypeBuilder*[T] = ref object
    ## A builder for creating a list of all known archetypes
    lookup: seq[T]
    allComponents: Bits
    archetypes: OpenSet[Bits]
    actions: OpenSet[BuilderAction]
    accessories: Bits

  ArchetypeAccum = ref object
    ## Used during the final calculation as an accumulator for the full set of archetypes.
    ##
    ## A walk state is split in two. The `core` is everything that decides which actions
    ## apply and which archetype the entity ends up in. Against it sits every inert
    ## accessory that can ride along with that core -- as one set of possibilities rather
    ## than a state of its own, because nothing in the graph can tell those states apart
    seen: OpenTable[Bits, Bits]
    workQueue: seq[Bits]
    output: OpenTable[Bits, Bits]

proc enqueue(accum: var ArchetypeAccum, core, inert: Bits) =
  ## Records a core as reachable along with the accessories that can come with it, and
  ## queues it if either is news. A core already walked has to be walked again when its
  ## accessories grow, since everything downstream of it inherited the smaller set
  if core.isEmpty and inert.isEmpty:
    return

  let slot = accum.seen.slotFor(core)
  let known = accum.seen.value(slot)
  if known.isNil:
    accum.seen.setValue(slot, inert)
    accum.workQueue.add(core)
  elif not (inert <= known):
    accum.seen.setValue(slot, known + inert)
    accum.workQueue.add(core)

proc newArchetypeBuilder*[T](): ArchetypeBuilder[T] =
  ## Creates a new ArchetypeBuilder
  ArchetypeBuilder[T](
    lookup: newSeq[T](256),
    allComponents: Bits(),
    archetypes: initOpenSet[Bits](),
    actions: initOpenSet[BuilderAction](),
    accessories: Bits(),
  )

template hashOrNil(value: untyped): Hash =
  ## `hash` for a part of an action that may not be there at all
  if value.isNil:
    Hash(0)
  else:
    value.hash

template eqOrNil(a, b: untyped): bool =
  ## `==` for a part of an action that may not be there at all
  if a.isNil or b.isNil:
    a.isNil and b.isNil
  else:
    a == b

proc hash*(action: BuilderAction): Hash =
  ## `bothDetach` follows from the other parts, so it takes no part in identity
  hashOrNil(action.filter) !& hashOrNil(action.attach) !& hashOrNil(action.detach) !&
    hashOrNil(action.optDetach)

proc `==`*(a, b: BuilderAction): bool =
  eqOrNil(a.filter, b.filter) and eqOrNil(a.attach, b.attach) and
    eqOrNil(a.detach, b.detach) and eqOrNil(a.optDetach, b.optDetach)

proc orNil(bits: Bits): Bits =
  ## An empty set asks for no work, so it is stored as nothing at all
  if bits.isNil or bits.isEmpty:
    nil
  else:
    bits

proc newAction(
    filter: BitsFilter = nil;
    attach: Bits = nil;
    detach: Bits = nil;
    optDetach: Bits = nil,
): BuilderAction =
  ## Builds an action, folding away every part of it that describes no work
  let required = detach.orNil
  let optional = optDetach.orNil
  BuilderAction(
    filter:
      if filter.acceptsAll:
        nil
      else:
        filter,
    attach: attach.orNil,
    detach: required,
    optDetach: optional,
    bothDetach:
      if required.isNil:
        optional
      elif optional.isNil:
        required
      else:
        required + optional,
  )

proc asBits[T](builder: var ArchetypeBuilder[T], values: openarray[T]): Bits =
  result = Bits()
  for value in values:
    if builder.lookup.len < value.uniqueId.int:
      builder.lookup.setLen(value.uniqueId * 2)
    builder.lookup[value.uniqueId] = value
    result.incl(value.uniqueId)

proc filter*[T](
    builder: var ArchetypeBuilder[T],
    mustContain: openarray[T],
    mustExclude: openarray[T],
): BitsFilter =
  newFilter(builder.asBits(mustContain), builder.asBits(mustExclude))

proc define*[T](builder: var ArchetypeBuilder[T], values: openarray[T]) =
  ## Adds a new archetype with specific values
  let bits = asBits(builder, values)
  builder.archetypes.incl(bits)
  builder.allComponents += bits

proc attachable*[T](
    builder: var ArchetypeBuilder[T], values: openarray[T], filter: BitsFilter
) =
  ## Describes components that can be attached to entities to create new archetypes
  let bits = asBits(builder, values)
  builder.actions.incl(newAction(filter = filter, attach = bits))
  builder.allComponents += bits

proc detachable*[T](
    builder: var ArchetypeBuilder[T], values: openarray[T], optional: openarray[T] = []
) =
  ## Describes components that can be detached from entities to create new archetypes
  builder.actions.incl(
    newAction(detach = asBits(builder, values), optDetach = asBits(builder, optional))
  )

proc accessory*[T](builder: var ArchetypeBuilder[T], value: T) =
  ## Marks that a value is an accessory and should not, itself, cause the creation of a new archetype
  builder.accessories.incl(value.uniqueId)

proc attachDetach*[T](
    builder: var ArchetypeBuilder[T],
    attach: openarray[T],
    detach: openarray[T],
    optDetach: openarray[T] = [],
    filter: BitsFilter = builder.filter([], []),
) =
  ## Describes components that can be attached to entities to create new archetypes
  let bits = asBits(builder, attach)
  builder.actions.incl(
    newAction(
      filter = filter,
      attach = bits,
      detach = asBits(builder, detach),
      optDetach = asBits(builder, optDetach),
    )
  )
  builder.allComponents += bits

iterator allComponents*[T](builder: ArchetypeBuilder[T]): T =
  ## Yields all the components register in a builder
  var seen = Bits()
  for bit in builder.allComponents.items:
    if bit notin seen:
      seen.incl(bit)
      yield builder.lookup[bit]

proc prepared(action: BuilderAction, gate: int, inert: Bits): BuilderAction =
  ## The copy of an action the walk actually runs.
  ##
  ## When there is a gate, the index only reaches this action through a component it
  ## requires, so by the time the walk gets here that component is known to be present
  ## and the filter no longer has to ask for it -- and a filter that wanted nothing else
  ## falls away entirely.
  ##
  ## The attached components get split across the two halves of a walk state at the same
  ## time, since the walk always wants them apart and never wants them together
  let filter =
    if gate < 0:
      action.filter
    else:
      action.filter.withoutRequired(gate.uint16)

  result = BuilderAction(
    filter:
      if filter.acceptsAll:
        nil
      else:
        filter,
    attach: action.attach,
    detach: action.detach,
    optDetach: action.optDetach,
    bothDetach: action.bothDetach,
  )

  if not action.attach.isNil:
    result.attachCore = (action.attach - inert).orNil
    result.attachInert = action.attach.intersect(inert).orNil

template applyAction(
    entry: BuilderAction, source, inert: Bits, accum: var ArchetypeAccum
) =
  ## Works out what `entry` turns a walk state into, and queues the result.
  let action = entry

  if action.filter.isNil or action.filter.matches(source):
    # An action that leaves the state untouched can never enqueue anything new, since
    # whatever it would produce is the state itself, which has already been seen
    let attaches = not action.attachCore.isNil and not (action.attachCore <= source)
    let detachesAll = not action.detach.isNil and action.detach <= source
    let detaches =
      detachesAll or
      (not action.optDetach.isNil and action.optDetach.anyIntersect(source))
    let gains = not action.attachInert.isNil and not (action.attachInert <= inert)

    if attaches or detaches or gains:
      let added =
        if attaches:
          action.attachCore
        else:
          nil

      # `detachesAll` was decided against `source`. Attaching only ever grows the set, so
      # a detach already contained in `source` is still contained afterwards -- it is only
      # a detach that missed which has to be asked about a second time
      let removed =
        if detachesAll or (
          attaches and not action.detach.isNil and
          action.detach.isSubsetOfUnion(source, action.attachCore)
        ):
          action.bothDetach
        else:
          action.optDetach

      # Neither half has to have the other's components filtered out of `removed` first:
      # a core never holds an inert accessory, and the accessories never hold a core
      # component, so each side only ever takes away what it already lacks
      accum.enqueue(
        combine(source, added, removed), combine(inert, action.attachInert, removed)
      )

proc addWork(index: ActionIndex, source, inert: Bits, accum: var ArchetypeAccum) =
  ## Applies every action that could possibly do anything to a walk state
  for i in 0 ..< index.ungated:
    applyAction(index.entries[i], source, inert, accum)

  # Everything else is filed under a component its filter requires, so walking the
  # components `source` actually has reaches every remaining candidate, and never looks
  # at the rest. An inert accessory is never one of them -- no filter mentions one
  for component in source.items:
    for i in index.gateStart[component.int] ..< index.gateEnd[component.int]:
      applyAction(index.entries[i], source, inert, accum)

proc process[T](
    builder: ArchetypeBuilder[T],
    actions: ActionIndex,
    core, inert: Bits,
    accum: var ArchetypeAccum,
) =
  ## Records an archetype and queues up everything reachable from it. Anything that
  ## made it onto the queue is already non-empty and marked as seen.

  # The minimal set of components, minus all the accessory components. The inert ones are
  # already out of the core, so only the rest are left to take away
  let minValues =
    if builder.accessories.isEmpty:
      core
    else:
      core - builder.accessories

  let next =
    if inert.isEmpty:
      core
    else:
      core + inert

  # Makes sure the registerd output includes any new accessories. A missing entry reads
  # back as a nil `Bits`, so claiming the slot up front keeps this to a single probe
  let slot = accum.output.slotFor(minValues)
  let existing = accum.output.value(slot)
  accum.output.setValue(
    slot,
    if existing.isNil:
      next
    else:
      existing + next,
  )

  actions.addWork(core, inert, accum)

proc inertAccessories[T](builder: ArchetypeBuilder[T]): Bits =
  ## The accessories nothing in the graph can tell apart.
  ##
  ## An accessory has to be searched for in its own right only when some action asks
  ## whether it is there: a filter that requires or excludes it, or a detach that will
  ## not apply without it. Any other one changes nothing about where an entity carrying
  ## it can go, and it is already left out of the key an archetype is recorded under, so
  ## the walk can carry it as one of a set of possibilities instead of splitting the
  ## whole search in two to hold both answers
  result = builder.accessories
  if result.isEmpty:
    return
  for action in builder.actions.items:
    if not action.filter.isNil:
      result = result - action.filter.mentioned
    if not action.detach.isNil:
      result = result - action.detach

proc buildIndex[T](builder: ArchetypeBuilder[T], inert: Bits): ActionIndex =
  ## Files every action under a component that gates it, picking the rarest component
  ## the filter requires so the gate rejects as often as it can.
  ##
  ## Rarity is judged against the archetypes that were explicitly defined, which is the
  ## only evidence available before the walk starts. It only has to be a decent guess:
  ## a poor gate costs a few wasted candidates, never a wrong answer
  var popularity = newSeq[int](builder.lookup.len)
  for archetype in builder.archetypes.items:
    for component in archetype.items:
      popularity[component.int] += 1

  var byGate = newSeq[seq[BuilderAction]](builder.lookup.len)
  var ungated: seq[BuilderAction]

  for action in builder.actions.items:
    var gate = -1
    if not action.filter.acceptsAll:
      for component in action.filter.required:
        if gate < 0 or popularity[component.int] < popularity[gate]:
          gate = component.int

    if gate < 0:
      ungated.add(action.prepared(gate, inert))
    else:
      byGate[gate].add(action.prepared(gate, inert))

  # Flattened into one array, so reaching an action costs a single index rather than one
  # per level of nesting -- which the walk pays for on every field it reads
  result = ActionIndex(
    entries: ungated,
    ungated: ungated.len,
    gateStart: newSeq[int](byGate.len),
    gateEnd: newSeq[int](byGate.len),
  )
  for component, actions in byGate:
    result.gateStart[component] = result.entries.len
    for action in actions:
      result.entries.add(action)
    result.gateEnd[component] = result.entries.len

proc build*[T](builder: ArchetypeBuilder[T]): ArchetypeSet[T] =
  ## Constructs the final set of archetypes

  var accum = ArchetypeAccum(
    workQueue: newSeqOfCap[Bits](256),
    seen: initOpenTable[Bits, Bits](256),
    output: initOpenTable[Bits, Bits](256),
  )

  # Worked out before anything is queued, because it decides how a state is even shaped
  let inert = builder.inertAccessories

  # Add in all the baseline archetypes
  for archetype in builder.archetypes.items:
    accum.enqueue(archetype - inert, archetype.intersect(inert))

  # Built once up front. The queue gets walked thousands of times over, and rebuilding
  # this for each pass costs more than everything the pass itself does
  let actions = builder.buildIndex(inert)

  while accum.workQueue.len > 0:
    let core = accum.workQueue.pop
    builder.process(actions, core, accum.seen[core], accum)

  var archetypes: seq[Archetype[T]]
  for minValues, bits in accum.output:
    var values: seq[T]
    for bit in bits.items:
      values.add(builder.lookup[bit])
    values.sort()
    # `bits` is already the exact component set, and everything it holds beyond
    # the table key is, by construction, an accessory
    archetypes.add(
      newArchetype(values, allComps = bits, accessoryComps = bits - minValues)
    )

  result = newArchetypeSet(archetypes, builder.accessories)
