import std/bitops, hashes

type
  Word = uint64

  Bits* = ref object
    ## A bitset without a limit on the number of bits that can be set.
    buckets: seq[Word]
    hashCached: bool
    cachedHash: Hash

  BitsFilter* = ref object
    ## Uses bitsets to determine whether another bit set 'matches' a set of conditions
    mustContain: Bits
    mustExclude: Bits

const wordBits = sizeof(Word) * 8
const maxBitMask = Word(1) shl (wordBits - 1)

proc calculate(value: uint16): tuple[bucket: uint16, mask: Word] =
  (bucket: value div wordBits, mask: maxBitMask shr (value mod wordBits))

proc incl*(bitset: var Bits, value: uint16) =
  ## Add a value to this set

  let (bucket, mask) = value.calculate

  if bitset.buckets.len < bucket.int + 1:
    bitset.buckets.setLen(bucket + 1)
    bitset.buckets[bucket] = mask
  else:
    let bucketValue = bitset.buckets[bucket]
    bitset.buckets[bucket] = bucketValue or mask

  bitset.hashCached = false

proc newBits*(values: varargs[uint16]): Bits =
  ## Create a new bit set
  result = Bits()
  for value in values:
    result.incl(value)

iterator items*(bitset: Bits): uint16 =
  ## Returns the index of every bit that has been set, from lowest to highest
  for i, value in bitset.buckets:
    var remaining = value
    while remaining != 0:
      let j = remaining.countLeadingZeroBits.uint16
      yield (i.uint16 * wordBits) + j
      remaining = remaining and not (maxBitMask shr j)

proc `$`*(bitset: Bits): string =
  result = "{"
  var isFirst = true
  for value in bitset:
    if isFirst:
      isFirst = false
    else:
      result &= ", "
    result &= $value
  result &= "}"

proc hash*(bitset: Bits): Hash =
  # FNV-1a over the raw words, followed by a finalizer. `std/hashes` would run Wang Yi's
  # mixer across every word, which costs millions of VM instructions over the course of
  # building a large archetype graph.
  if not bitset.hashCached:
    var accum = 0xcbf29ce484222325'u64
    for value in bitset.buckets:
      accum = (accum xor value) * 0x100000001b3'u64
    accum = accum xor (accum shr 33)
    accum = accum * 0xff51afd7ed558ccd'u64
    bitset.cachedHash = cast[Hash](accum xor (accum shr 33))
    bitset.hashCached = true
  return bitset.cachedHash

proc contains*(bitset: Bits, value: uint16): bool =
  ## Returns whether any of the bits overlap
  let (bucket, mask) = value.calculate
  if bitset.buckets.len < bucket.int + 1:
    return false
  else:
    return (bitset.buckets[bucket] and mask) > 0

proc card*(bitset: Bits): int =
  ## The number of bits that have been set -- the cardinality
  for value in bitset.buckets:
    result += value.countSetBits

proc isEmpty*(bitset: Bits): bool =
  ## Whether no bits at all are set
  bitset.buckets.len == 0

iterator eachValue(a, b: Bits): (int, (Word, Word)) =
  let minLen = min(a.buckets.len, b.buckets.len)
  for i in 0 ..< minLen:
    yield (i, (a.buckets[i], b.buckets[i]))
  if a.buckets.len < b.buckets.len:
    for i in a.buckets.len ..< b.buckets.len:
      yield (i, (Word(0), b.buckets[i]))
  elif b.buckets.len < a.buckets.len:
    for i in b.buckets.len ..< a.buckets.len:
      yield (i, (a.buckets[i], Word(0)))

proc `==`*(a, b: Bits): bool =
  ## Returns whether two sets contain the exact same set of values
  if a.buckets.len != b.buckets.len:
    return false

  for i in 0 ..< a.buckets.len:
    if a.buckets[i] != b.buckets[i]:
      return false
  return true

proc `+=`*(a: var Bits, b: Bits) =
  ## Union of two sets
  a.buckets.setLen(max(a.buckets.len, b.buckets.len))
  for i, (aValue, bValue) in eachValue(a, b):
    a.buckets[i] = aValue or bValue
  a.hashCached = false

proc `+`*(a, b: Bits): Bits =
  ## Union of two sets
  let overlap = min(a.buckets.len, b.buckets.len)
  result = Bits(buckets: newSeq[Word](max(a.buckets.len, b.buckets.len)))
  for i in 0 ..< overlap:
    result.buckets[i] = a.buckets[i] or b.buckets[i]
  # Only one of these can have trailing buckets past the overlap
  for i in overlap ..< a.buckets.len:
    result.buckets[i] = a.buckets[i]
  for i in overlap ..< b.buckets.len:
    result.buckets[i] = b.buckets[i]

proc `-`*(a, b: Bits): Bits =
  ## Remove elements of set `b` from set `a` and return the new value
  let overlap = min(a.buckets.len, b.buckets.len)
  result = Bits(buckets: newSeq[Word](max(a.buckets.len, b.buckets.len)))
  var maxBucket = -1
  for i in 0 ..< overlap:
    let newValue = a.buckets[i] and (not b.buckets[i])
    if newValue != 0:
      result.buckets[i] = newValue
      maxBucket = i
  # Buckets past the end of `b` have nothing to remove, and buckets past the end
  # of `a` are empty to begin with
  for i in overlap ..< a.buckets.len:
    if a.buckets[i] != 0:
      result.buckets[i] = a.buckets[i]
      maxBucket = i
  # Trailing empty buckets get trimmed all the way down, so subtracting a set from itself
  # produces something that hashes and compares equal to a set that was never populated
  if maxBucket + 1 != result.buckets.len:
    result.buckets.setLen(maxBucket + 1)

proc combine*(source, attach, remove: Bits): Bits =
  ## `(source + attach) - remove` in a single pass. Either `attach` or `remove` may be
  ## nil, meaning there is nothing to add or nothing to take away.
  let sourceLen = source.buckets.len
  let attachLen =
    if attach.isNil:
      0
    else:
      attach.buckets.len
  let removeLen =
    if remove.isNil:
      0
    else:
      remove.buckets.len

  result = Bits(buckets: newSeq[Word](max(sourceLen, attachLen)))
  var maxBucket = -1
  for i in 0 ..< result.buckets.len:
    var value: Word = 0
    if i < sourceLen:
      value = source.buckets[i]
    if i < attachLen:
      value = value or attach.buckets[i]
    if i < removeLen:
      value = value and not remove.buckets[i]
    if value != 0:
      result.buckets[i] = value
      maxBucket = i
  if maxBucket + 1 != result.buckets.len:
    result.buckets.setLen(maxBucket + 1)

proc intersect*(a, b: Bits): Bits =
  ## The bits the two sets have in common
  # Past the overlap one side is empty, so nothing there survives
  let overlap = min(a.buckets.len, b.buckets.len)
  result = Bits(buckets: newSeq[Word](overlap))
  var maxBucket = -1
  for i in 0 ..< overlap:
    let value = a.buckets[i] and b.buckets[i]
    if value != 0:
      result.buckets[i] = value
      maxBucket = i
  if maxBucket + 1 != result.buckets.len:
    result.buckets.setLen(maxBucket + 1)

proc `<=`*(a, b: Bits): bool =
  ## Returns whether a is a subset of b
  let aLen = a.buckets.len
  if aLen > b.buckets.len:
    return false
  # Anything past the end of `a` is empty, so it is trivially contained by `b`
  for i in 0 ..< aLen:
    if ((not b.buckets[i]) and a.buckets[i]) > 0:
      return false
  return true

proc isSubsetOfUnion*(a, b, c: Bits): bool =
  ## Whether `a` is a subset of `b + c`, without building the union to find out
  let bLen = b.buckets.len
  let cLen = c.buckets.len
  if a.buckets.len > max(bLen, cLen):
    return false
  for i in 0 ..< a.buckets.len:
    var available: Word = 0
    if i < bLen:
      available = b.buckets[i]
    if i < cLen:
      available = available or c.buckets[i]
    if ((not available) and a.buckets[i]) > 0:
      return false
  return true

proc `<`*(a, b: Bits): bool =
  ## Returns whether a is a strict subset of b. Nim derives `>` from this
  ## automatically, which gives back a strict superset check
  result = false
  for i, (aValue, bValue) in eachValue(a, b):
    if ((not bValue) and aValue) > 0:
      return false
    elif aValue != bValue:
      result = true

proc anyIntersect*(a, b: Bits): bool =
  ## Returns whether any of the bits overlap
  # Past the overlap one side is empty, so nothing there can intersect
  for i in 0 ..< min(a.buckets.len, b.buckets.len):
    if (b.buckets[i] and a.buckets[i]) > 0:
      return true
  return false

proc newFilter*(mustContain, mustExclude: Bits): BitsFilter =
  ## Creates a new filter
  BitsFilter(mustContain: mustContain, mustExclude: mustExclude)

iterator required*(filter: BitsFilter): uint16 =
  ## Yields every component a filter insists on being present. A set missing any one of
  ## these can never match, which makes them usable as a cheap precondition
  for bit in filter.mustContain.items:
    yield bit

proc mentioned*(filter: BitsFilter): Bits =
  ## Every component a filter asks after, whether it insists on one or rules it out.
  ## A caller that wants to know which components a filter can tell apart wants this
  if filter.isNil:
    Bits()
  else:
    filter.mustContain + filter.mustExclude

proc acceptsAll*(filter: BitsFilter): bool =
  ## Whether this filter lets through every possible set of bits
  filter.isNil or (filter.mustContain.isEmpty and filter.mustExclude.isEmpty)

proc withoutRequired*(filter: BitsFilter, component: uint16): BitsFilter =
  ## The same filter, minus one component it requires. Useful where a caller has already
  ## established that component is present and would rather not pay to confirm it
  BitsFilter(
    mustContain: filter.mustContain - newBits(component),
    mustExclude: filter.mustExclude,
  )

proc matches*(filter: BitsFilter, all: Bits): bool =
  ## Whether a target matches a filter
  let allLen = all.buckets.len
  let containLen = filter.mustContain.buckets.len
  if containLen > allLen:
    return false
  for i in 0 ..< containLen:
    if ((not all.buckets[i]) and filter.mustContain.buckets[i]) > 0:
      return false
  let excludeLen = min(filter.mustExclude.buckets.len, allLen)
  for i in 0 ..< excludeLen:
    if (filter.mustExclude.buckets[i] and all.buckets[i]) > 0:
      return false
  return true

proc matches*(filter: BitsFilter, all: Bits, optional: Bits): bool =
  ## Whether a target matches a filter, disregarding any optional components
  if optional.isEmpty:
    return filter.matches(all)
  return
    filter.mustContain <= all and not (all - optional).anyIntersect(filter.mustExclude)

proc `==`*(a, b: BitsFilter): bool =
  if a.isNil or b.isNil:
    return a.isNil and b.isNil
  return a.mustContain == b.mustContain and a.mustExclude == b.mustExclude

proc hash*(filter: BitsFilter): Hash =
  filter.mustContain.hash !& filter.mustExclude.hash
