import std/hashes

## Open addressed hash containers, hand rolled for the Nim VM.
##
## Everything Necsus does with a hash table happens while compiling, and `std/tables` and
## `std/sets` are surprisingly expensive there. Every lookup goes through the generic
## `hashcommon.rawGet` machinery, and `std/hashes` runs Wang Yi's mixer over each word of
## each key. Between them they account for a few million VM instructions when building
## the archetype graph for a large app.
##
## These are deliberately plainer:
##
## * Entries live in flat, parallel seqs. The bucket array holds nothing but integers, so
##   probing only reaches for a key once a hash code has already matched.
## * A bucket holds one plus an index into those seqs, which lets zero mean "empty"
##   without having to prefill anything.
## * There is no `del`. Nothing here needs it, and leaving it out means a probe can stop
##   at the first empty bucket rather than walking past tombstones.
##
## Insertion order is preserved, so iteration is stable across compiles -- which matters
## when the output feeds code generation.
##
## As with `std/tables`, a bucket is picked from the low bits of `hash`, and probing is
## linear. A key type whose hash leaves its low bits poorly mixed will cluster, and that
## shows up as a slow compile rather than as a wrong answer.

const defaultBuckets = 64
  ## Number of buckets a container starts with. Must be a power of two

const growthFactor = 4
  ## How much the bucket array grows by when it fills up. Growing in bigger steps trades
  ## a little memory for fewer `newSeq` calls, which are what a rehash actually costs

type
  OpenTable*[K, V] = object ## An open addressed hash table
    buckets: seq[int]
    codes: seq[int]
    entryKeys: seq[K]
    entryValues: seq[V]

  OpenSet*[K] = object
    ## An open addressed hash set. Laid out like `OpenTable`, minus the values
    buckets: seq[int]
    codes: seq[int]
    entryKeys: seq[K]

proc bucketsFor(expected: int): int =
  ## The bucket array gets rebuilt once it is half full, so it has to be twice the number
  ## of entries it should be able to hold without rehashing
  result = defaultBuckets
  while result < expected * 2:
    result = result * 2

template hashCodeOf(key: untyped): int =
  ## Hash codes come from user code, so they can be any integer at all -- including
  ## negative ones, which would index off the front of the bucket array
  int(hash(key)) and 0x3FFFFFFF

template findBucket(store, wanted, code: untyped): int =
  ## The bucket that `wanted` belongs in. A zero there means the key isn't in the
  ## container yet, and that this is the bucket it should be recorded in
  block:
    let wrap = store.buckets.len - 1
    var bucket = code and wrap
    while true:
      let entry = store.buckets[bucket]
      if entry == 0:
        break
      elif store.codes[entry - 1] == code and store.entryKeys[entry - 1] == wanted:
        break
      bucket = (bucket + 1) and wrap
    bucket

template reindex(store: untyped) =
  ## Rebuilds the bucket array against a fresh, larger one
  store.buckets = newSeq[int](store.buckets.len * growthFactor)
  let wrap = store.buckets.len - 1
  for i, code in store.codes:
    var bucket = code and wrap
    while store.buckets[bucket] != 0:
      bucket = (bucket + 1) and wrap
    store.buckets[bucket] = i + 1

template link(store, bucket: untyped) =
  ## Points `bucket` at the entry that was just appended, growing the bucket array once
  ## it passes half full. Linear probing degrades badly beyond that
  store.buckets[bucket] = store.codes.len
  if store.codes.len * 2 >= store.buckets.len:
    reindex(store)

template ensureBuckets(store: untyped) =
  ## These are plain objects, so one can come into existence without ever being passed
  ## through `initOpenTable` or `initOpenSet`
  if store.buckets.len == 0:
    store.buckets = newSeq[int](defaultBuckets)

proc initOpenTable*[K, V](expected: int = 32): OpenTable[K, V] =
  ## Creates a table sized to hold `expected` entries without rehashing
  OpenTable[K, V](buckets: newSeq[int](bucketsFor(expected)))

proc len*[K, V](table: OpenTable[K, V]): int =
  table.entryKeys.len

proc find[K, V](table: OpenTable[K, V], key: K): int =
  ## The slot holding `key`, or `-1` if it isn't in the table
  mixin hash, `==`
  if table.entryKeys.len == 0:
    return -1
  return table.buckets[findBucket(table, key, hashCodeOf(key))] - 1

proc slotFor*[K, V](table: var OpenTable[K, V], key: K): int =
  ## The slot holding `key`, adding one that holds a default value if the key isn't in
  ## the table yet. Slots stay valid for the life of the table
  mixin hash, `==`
  ensureBuckets(table)
  let code = hashCodeOf(key)
  let bucket = findBucket(table, key, code)
  let entry = table.buckets[bucket]
  if entry != 0:
    return entry - 1

  table.codes.add(code)
  table.entryKeys.add(key)
  table.entryValues.add(default(V))
  link(table, bucket)
  return table.entryKeys.len - 1

proc key*[K, V](table: OpenTable[K, V], slot: int): K =
  ## The key held in a slot handed back by `slotFor`
  table.entryKeys[slot]

proc value*[K, V](table: OpenTable[K, V], slot: int): V =
  ## The value held in a slot handed back by `slotFor`
  table.entryValues[slot]

proc setValue*[K, V](table: var OpenTable[K, V], slot: int, value: sink V) =
  ## Replaces the value held in a slot handed back by `slotFor`
  table.entryValues[slot] = value

proc contains*[K, V](table: OpenTable[K, V], key: K): bool =
  table.find(key) >= 0

proc `[]`*[K, V](table: OpenTable[K, V], key: K): V =
  ## The value stored against `key`, which has to be present
  let slot = table.find(key)
  if slot < 0:
    raise newException(KeyError, "key not found")
  return table.entryValues[slot]

proc getOrDefault*[K, V](table: OpenTable[K, V], key: K): V =
  ## The value stored against `key`, or a default value when it is missing
  let slot = table.find(key)
  return
    if slot < 0:
      default(V)
    else:
      table.entryValues[slot]

proc `[]=`*[K, V](table: var OpenTable[K, V], key: K, value: sink V) =
  ## Stores `value` against `key`, replacing anything already there
  table.entryValues[table.slotFor(key)] = value

iterator pairs*[K, V](table: OpenTable[K, V]): (K, V) =
  ## Yields every key and value, in the order they were added
  for i in 0 ..< table.entryKeys.len:
    yield (table.entryKeys[i], table.entryValues[i])

iterator keys*[K, V](table: OpenTable[K, V]): K =
  ## Yields every key, in the order they were added
  for i in 0 ..< table.entryKeys.len:
    yield table.entryKeys[i]

iterator values*[K, V](table: OpenTable[K, V]): V =
  ## Yields every value, in the order its key was added
  for i in 0 ..< table.entryValues.len:
    yield table.entryValues[i]

proc initOpenSet*[K](expected: int = 32): OpenSet[K] =
  ## Creates a set sized to hold `expected` entries without rehashing
  OpenSet[K](buckets: newSeq[int](bucketsFor(expected)))

proc len*[K](openSet: OpenSet[K]): int =
  openSet.entryKeys.len

proc card*[K](openSet: OpenSet[K]): int =
  openSet.entryKeys.len

proc contains*[K](openSet: OpenSet[K], key: K): bool =
  mixin hash, `==`
  if openSet.entryKeys.len == 0:
    return false
  return openSet.buckets[findBucket(openSet, key, hashCodeOf(key))] != 0

proc containsOrIncl*[K](openSet: var OpenSet[K], key: K): bool =
  ## Adds `key` and returns whether it was already there. This is the primitive worth
  ## reaching for -- a `contains` followed by an `incl` probes twice
  mixin hash, `==`
  ensureBuckets(openSet)
  let code = hashCodeOf(key)
  let bucket = findBucket(openSet, key, code)
  if openSet.buckets[bucket] != 0:
    return true

  openSet.codes.add(code)
  openSet.entryKeys.add(key)
  link(openSet, bucket)
  return false

proc incl*[K](openSet: var OpenSet[K], key: K) =
  ## Adds `key`, doing nothing if it is already there
  discard openSet.containsOrIncl(key)

iterator items*[K](openSet: OpenSet[K]): K =
  ## Yields every key, in the order they were added
  for i in 0 ..< openSet.entryKeys.len:
    yield openSet.entryKeys[i]
