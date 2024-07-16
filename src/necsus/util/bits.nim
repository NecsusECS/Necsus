import std/bitops, hashes, options

type
    Word = uint64

    Bits* = ref object
        ## A bitset without a limit on the number of bits that can be set
        buckets: seq[Word]
        cachedHash: Option[Hash]

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

    bitset.cachedHash = none(Hash)

proc newBits*(values: varargs[uint16]): Bits =
    ## Create a new bit set
    result = Bits()
    for value in values:
        result.incl(value)

iterator items*(bitset: Bits): uint16 =
    ## Returns the index of every bit that has been set
    for i, value in bitset.buckets:
        var bitcheck = maxBitMask
        for j in 0'u16..<wordBits:
            if (value and bitcheck) > 0:
                yield (i.uint16 * wordBits) + j
            bitcheck = bitcheck shr 1

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
    if bitset.cachedHash.isNone:
        var accum = 0.hash
        for value in bitset.buckets:
            accum = accum !& hash(value)
        bitset.cachedHash = some(accum)
    return bitset.cachedHash.get

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

iterator eachValue(a, b: Bits): (int, (Word, Word)) =
    let minLen = min(a.buckets.len, b.buckets.len)
    for i in 0..<minLen:
        yield (i, (a.buckets[i], b.buckets[i]))
    if a.buckets.len < b.buckets.len:
        for i in a.buckets.len..<b.buckets.len:
            yield (i, (Word(0), b.buckets[i]))
    elif b.buckets.len < a.buckets.len:
        for i in b.buckets.len..<a.buckets.len:
            yield (i, (a.buckets[i], Word(0)))

proc `==`*(a, b: Bits): bool =
    ## Returns whether two sets contain the exact same set of values
    if a.buckets.len != b.buckets.len:
        return false

    for _, (aValue, bValue) in eachValue(a, b):
        if aValue != bValue:
            return false
    return true

proc `+`*(a, b: Bits): Bits =
    ## Union of two sets
    result = Bits(buckets: newSeq[Word](max(a.buckets.len, b.buckets.len)))
    for i, (aValue, bValue) in eachValue(a, b):
        result.buckets[i] = aValue or bValue

proc `-`*(a, b: Bits): Bits =
    ## Remove elements of set `b` from set `a` and return the new value
    result = Bits(buckets: newSeq[Word](max(a.buckets.len, b.buckets.len)))
    var maxBucket = 0
    for i, (aValue, bValue) in eachValue(a, b):
        let newValue = aValue and (not bValue)
        if newValue != 0:
            result.buckets[i] = newValue
            maxBucket = i
    result.buckets.setLen(maxBucket + 1)

proc `<=`*(a, b: Bits): bool =
    ## Returns whether a is a subset of b
    for i, (aValue, bValue) in eachValue(a, b):
        if ((not bValue) and aValue) > 0:
            return false
    return true

proc `<`*(a, b: Bits): bool =
    ## Returns whether a is a strict subset of b
    result = false
    for i, (aValue, bValue) in eachValue(a, b):
        if ((not bValue) and aValue) > 0:
            return false
        elif aValue != bValue:
            result = true

proc anyIntersect*(a, b: Bits): bool =
    ## Returns whether any of the bits overlap
    for i, (aValue, bValue) in eachValue(a, b):
        if (bValue and aValue) > 0:
            return true
    return false

proc newFilter*(mustContain, mustExclude: Bits): BitsFilter =
    ## Creates a new filter
    BitsFilter(mustContain: mustContain, mustExclude: mustExclude)

proc matches*(target: Bits, filter: BitsFilter): bool =
    ## Whether a target matches a filter
    let targetLen = target.buckets.len
    let mustContainLen = filter.mustContain.buckets.len
    if targetLen < mustContainLen:
        return false
    let mustExcludeLen = filter.mustExclude.buckets.len
    for i in 0..<targetLen:
        let found = target.buckets[i]

        if i < mustContainLen:
            let mustContain = filter.mustContain.buckets[i]
            if (mustContain and found) != mustContain:
                return false

        if i < mustExcludeLen and (found and filter.mustExclude.buckets[i]) > 0:
            return false

    return true

proc hash*(filter: BitsFilter): Hash = filter.mustContain.hash !& filter.mustExclude.hash