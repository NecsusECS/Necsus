import archetype, algorithm, ../util/[bits, openAddr], hashes

export archetype, bits.hash, bits.`$`, bits.`==`

type
  BuilderAction = object
    ## A single way of moving from one archetype to another.
    filter: BitsFilter
    attach, detach, optDetach: Bits

  PreparedAction = ref object
    ## `BuilderAction` folded down for the graph walk. A field is nil when the walk can
    ## skip that part of the work outright, so the hot loop tests for nil instead of
    ## re-deriving emptiness from the bitsets on every pass.
    ## `bothDetach is `detach` and `optDetach` together, so an action that does
    ## both still only takes a single pass to apply
    filter: BitsFilter
    attach, detach, optDetach, bothDetach: Bits

  ActionIndex = object
    ## Actions arranged so that a single archetype only has to look at the ones that
    ## stand a chance of applying to it.
    ##
    ## An action whose filter requires a component can never fire against an archetype
    ## missing it, so each such action is filed under one of the components it requires.
    ## Walking an archetype's own components then reaches every candidate, and never
    ## looks at the rest. On a large app this is the difference between evaluating every
    ## action against every archetype and evaluating a small fraction of them
    entries: seq[PreparedAction]
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
    ## Used during the final calculation as an accumulator for the full set of archetypes
    seen: OpenSet[Bits]
    workQueue: seq[Bits]
    output: OpenTable[Bits, Bits]

proc enqueue(accum: var ArchetypeAccum, bits: Bits) =
  ## Queues a set of components to be processed, if it hasn't been queued already
  if not bits.isEmpty and not accum.seen.containsOrIncl(bits):
    accum.workQueue.add(bits)

proc newArchetypeBuilder*[T](): ArchetypeBuilder[T] =
  ## Creates a new ArchetypeBuilder
  ArchetypeBuilder[T](
    lookup: newSeq[T](256),
    allComponents: Bits(),
    archetypes: initOpenSet[Bits](),
    actions: initOpenSet[BuilderAction](),
    accessories: Bits(),
  )

proc hash*(action: BuilderAction): Hash =
  action.filter.hash !& action.attach.hash !& action.detach.hash !& action.optDetach.hash

proc `==`*(a, b: BuilderAction): bool =
  a.filter == b.filter and a.attach == b.attach and a.detach == b.detach and
    a.optDetach == b.optDetach

proc newAction(
    filter: BitsFilter = nil;
    attach: Bits = nil;
    detach: Bits = nil;
    optDetach: Bits = nil,
): BuilderAction =
  ## Builds an action with every part filled in, so nothing downstream has to reason
  ## about nil. An omitted part becomes an empty set, which every operation treats as
  ## the no-op it is
  BuilderAction(
    filter: if filter.isNil: newFilter(Bits(), Bits()) else: filter,
    attach: if attach.isNil: Bits() else: attach,
    detach: if detach.isNil: Bits() else: detach,
    optDetach: if optDetach.isNil: Bits() else: optDetach,
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

proc prepare(action: BuilderAction): PreparedAction =
  ## Nils out every part of an action that the graph walk can skip. A filter that lets
  ## everything through, an empty attach set and an empty detach set all describe work
  ## that would produce `source` right back again
  let both = action.detach + action.optDetach
  PreparedAction(
    filter: if action.filter.acceptsAll: nil else: action.filter,
    attach: if action.attach.isEmpty: nil else: action.attach,
    detach: if action.detach.isEmpty: nil else: action.detach,
    optDetach: if action.optDetach.isEmpty: nil else: action.optDetach,
    bothDetach: if both.isEmpty: nil else: both,
  )

template applyAction(entry: PreparedAction, source: Bits, accum: var ArchetypeAccum) =
  ## Works out what `entry` turns `source` into, and queues the result.
  let action = entry

  if action.filter.isNil or action.filter.matches(source):
    # An action that leaves `source` untouched can never enqueue anything new, since
    # whatever it would produce is `source`, which has already been seen
    let attaches = not action.attach.isNil and not (action.attach <= source)
    let detachesAll = not action.detach.isNil and action.detach <= source
    let detaches =
      detachesAll or
      (not action.optDetach.isNil and action.optDetach.anyIntersect(source))

    if attaches or detaches:
      let added =
        if attaches:
          action.attach
        else:
          nil

      # `detachesAll` was decided against `source`. Attaching only ever grows the set, so
      # a detach already contained in `source` is still contained afterwards -- it is only
      # a detach that missed which has to be asked about a second time
      let removed =
        if detachesAll or (
          attaches and not action.detach.isNil and
          action.detach.isSubsetOfUnion(source, action.attach)
        ):
          action.bothDetach
        else:
          action.optDetach

      accum.enqueue(combine(source, added, removed))

proc addWork(index: ActionIndex, source: Bits, accum: var ArchetypeAccum) =
  ## Applies every action that could possibly do anything to `source`
  for i in 0 ..< index.ungated:
    applyAction(index.entries[i], source, accum)

  # Everything else is filed under a component its filter requires, so walking the
  # components `source` actually has reaches every remaining candidate, and never looks
  # at the rest
  for component in source.items:
    for i in index.gateStart[component.int] ..< index.gateEnd[component.int]:
      applyAction(index.entries[i], source, accum)

proc process[T](
    builder: ArchetypeBuilder[T],
    actions: ActionIndex,
    next: Bits,
    accum: var ArchetypeAccum,
) =
  ## Records an archetype and queues up everything reachable from it. Anything that
  ## made it onto the queue is already non-empty and marked as seen.

  # The minimal set of components, minus all the accessory components
  let minValues =
    if builder.accessories.isEmpty:
      next
    else:
      next - builder.accessories

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

  actions.addWork(next, accum)

proc buildIndex[T](builder: ArchetypeBuilder[T]): ActionIndex =
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

  var gated = newSeq[seq[PreparedAction]](builder.lookup.len)
  var ungated: seq[PreparedAction]

  for action in builder.actions.items:
    let prepared = action.prepare

    var gate = -1
    if not prepared.filter.isNil:
      for component in prepared.filter.required:
        if gate < 0 or popularity[component.int] < popularity[gate]:
          gate = component.int

    if gate < 0:
      ungated.add(prepared)
    else:
      gated[gate].add(prepared)

  # Flattened into one array, so reaching an action costs a single index rather than one
  # per level of nesting -- which the walk pays for on every field it reads
  result = ActionIndex(
    entries: ungated,
    ungated: ungated.len,
    gateStart: newSeq[int](gated.len),
    gateEnd: newSeq[int](gated.len),
  )
  for component, actions in gated:
    result.gateStart[component] = result.entries.len
    for action in actions:
      result.entries.add(action)
    result.gateEnd[component] = result.entries.len

proc build*[T](builder: ArchetypeBuilder[T]): ArchetypeSet[T] =
  ## Constructs the final set of archetypes

  var accum = ArchetypeAccum(
    workQueue: newSeqOfCap[Bits](256),
    seen: initOpenSet[Bits](256),
    output: initOpenTable[Bits, Bits](256),
  )

  # Add in all the baseline archetypes
  for archetype in builder.archetypes.items:
    accum.enqueue(archetype)

  # Built once up front. The queue gets walked thousands of times over, and rebuilding
  # this for each pass costs more than everything the pass itself does
  let actions = builder.buildIndex

  while accum.workQueue.len > 0:
    builder.process(actions, accum.workQueue.pop, accum)

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
