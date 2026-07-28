import sequtils, archetype, algorithm, ../util/[bits, openAddr], hashes

export archetype, bits.hash, bits.`$`, bits.`==`

type
  BuilderAction = object
    ## A single way of moving from one archetype to another.
    filter: BitsFilter
    attach, detach, optDetach: Bits

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

proc addWork(
    actions: openArray[BuilderAction], source: Bits, accum: var ArchetypeAccum
) =
  for i in 0 ..< actions.len:
    template action(): untyped =
      ## Allows iteration using the index to avoid copying each action
      actions[i]

    if not action.filter.acceptsAll and not action.filter.matches(source):
      continue

    # An action that leaves `source` untouched can never enqueue anything new, since
    # whatever it would produce is `source`, which has already been seen
    let attaches = not (action.attach <= source)
    let detachesAll = not action.detach.isEmpty and action.detach <= source
    let detaches = detachesAll or action.optDetach.anyIntersect(source)
    if not attaches and not detaches:
      continue

    var variant = source
    if attaches:
      variant = variant + action.attach
    # Without an attach, `variant` is still `source`, so the subset test above stands.
    # With one, `variant` only grew, so a set already contained in `source` is still
    # contained -- only a detach that missed needs asking about a second time
    if detachesAll or (attaches and action.detach <= variant):
      variant = variant - action.detach
    if not action.optDetach.isEmpty:
      variant = variant - action.optDetach
    accum.enqueue(variant)

proc process[T](
    builder: ArchetypeBuilder[T],
    actions: openArray[BuilderAction],
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

  # Flattened once up front. The queue gets walked thousands of times over, and rebuilding
  # this for each pass costs more than everything the pass itself does
  let actions = builder.actions.toSeq

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
