import tables, sets, sequtils, archetype, algorithm, ../util/bits, hashes

export archetype, bits.hash, bits.`$`, bits.`==`

type
  BuilderAction = object
    case filtered: bool
    of true: filter: BitsFilter
    of false: discard

    case attaching: bool
    of true: attach: Bits
    of false: discard

    case detaching: bool
    of true:
      detach: Bits
      optDetach: Bits
    of false:
      discard

  ArchetypeBuilder*[T] = ref object
    ## A builder for creating a list of all known archetypes
    lookup: seq[T]
    allComponents: Bits
    archetypes: HashSet[Bits]
    actions: HashSet[BuilderAction]
    accessories: Bits

  ArchetypeAccum = ref object
    ## Used during the final calculation as an accumulator for the full set of archetypes
    seen: HashSet[Bits]
    workQueue: seq[Bits]
    output: Table[Bits, Bits]

proc enqueue(accum: var ArchetypeAccum, bits: Bits) =
  ## Queues a set of components to be processed, if it hasn't been queued already
  if bits.card > 0 and bits notin accum.seen:
    accum.seen.incl(bits)
    accum.workQueue.add(bits)

proc newArchetypeBuilder*[T](): ArchetypeBuilder[T] =
  ## Creates a new ArchetypeBuilder
  ArchetypeBuilder[T](
    lookup: newSeq[T](256),
    allComponents: Bits(),
    archetypes: initHashSet[Bits](),
    actions: initHashSet[BuilderAction](),
    accessories: Bits(),
  )

proc hash*(action: BuilderAction): Hash =
  if action.filtered:
    result = action.filter.hash
  if action.attaching:
    result = result !& action.attach.hash
  if action.detaching:
    result = result !& action.detach.hash !& action.optDetach.hash

proc `==`*(a, b: BuilderAction): bool =
  if a.filtered != b.filtered or a.attaching != b.attaching or a.detaching != b.detaching:
    return false
  elif a.filtered and a.filter != b.filter:
    return false
  elif a.attaching and a.attach != b.attach:
    return false
  elif a.detaching and (a.detach != b.detach or a.optDetach != b.optDetach):
    return false
  else:
    return true

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
  builder.actions.incl(
    BuilderAction(filtered: true, filter: filter, attaching: true, attach: bits)
  )
  builder.allComponents += bits

proc detachable*[T](
    builder: var ArchetypeBuilder[T], values: openarray[T], optional: openarray[T] = []
) =
  ## Describes components that can be detached from entities to create new archetypes
  builder.actions.incl(
    BuilderAction(
      detaching: true,
      detach: asBits(builder, values),
      optDetach: asBits(builder, optional),
    )
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
    BuilderAction(
      filtered: true,
      filter: filter,
      attaching: true,
      attach: bits,
      detaching: true,
      detach: asBits(builder, detach),
      optDetach: asBits(builder, optDetach),
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

    if action.filtered and not action.filter.matches(source):
      continue

    # An action that leaves `source` untouched can never enqueue anything, since
    let attaches = action.attaching and not (action.attach <= source)
    let detaches =
      action.detaching and (
        (action.detach.card > 0 and action.detach <= source) or
        action.optDetach.anyIntersect(source)
      )
    if not attaches and not detaches:
      continue

    var variant = source
    if action.attaching:
      variant = variant + action.attach
    if action.detaching:
      if action.detach <= variant:
        variant = variant - action.detach
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
  var minValues = next - builder.accessories

  # Makes sure the registerd output includes any new accessories
  if minValues in accum.output:
    accum.output[minValues] = accum.output[minValues] + next
  else:
    accum.output[minValues] = next

  actions.addWork(next, accum)

proc build*[T](builder: ArchetypeBuilder[T]): ArchetypeSet[T] =
  ## Constructs the final set of archetypes

  var accum = ArchetypeAccum(
    workQueue: newSeqOfCap[Bits](256),
    seen: initHashSet[Bits](256),
    output: initTable[Bits, Bits](256),
  )

  # Add in all the baseline archetypes
  for archetype in builder.archetypes.items:
    accum.enqueue(archetype)

  while accum.workQueue.len > 0:
    builder.process(builder.actions.toSeq, accum.workQueue.pop, accum)

  var archetypes: seq[Archetype[T]]
  for _, bits in accum.output:
    var values: seq[T]
    for bit in bits.items:
      values.add(builder.lookup[bit])
    values.sort()
    archetypes.add(newArchetype(values, builder.accessories))

  result = newArchetypeSet(archetypes, builder.accessories)
