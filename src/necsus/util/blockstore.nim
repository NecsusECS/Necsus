import std/[deques, options]

const bitsPerWord = 64

type
  BlockStoreObj[V] = object
    nextId: uint
    hasRecycledValues: bool
    recycle: Deque[uint]
    data: seq[V]
    liveness: seq[uint64]
    len: Natural

  BlockStore*[V] = ref BlockStoreObj[V] ## Stores a block of packed values

  Entry*[V] = object
    ## A reserved slot in a `BlockStore`. Liveness is tracked in a bitmap alongside the
    ## values instead of inline, which keeps the stored rows free of bookkeeping
    store: ptr BlockStoreObj[V]
    idx: uint

  BlockIter* = object
    index: uint
    isDone: bool

  BlockSpan* = object
    ## Every slot a store had handed out at the moment the span was taken, described in
    ## raw terms so a caller can walk it without going back through the store for each one.
    ## The slots are laid out end to end, so walking is a matter of stepping a pointer
    base: pointer
    liveness: ptr UncheckedArray[uint64]
    count: uint
    stride: uint

template wordOf(idx: uint): int =
  int(idx div bitsPerWord)

template bitOf(idx: uint): uint64 =
  1'u64 shl (idx mod bitsPerWord)

proc wordsFor(size: Natural): Natural =
  ## The number of bitmap words needed to track `size` values
  Natural((size + bitsPerWord - 1) div bitsPerWord)

proc newBlockStore*[V](size: Natural): BlockStore[V] =
  ## Instantiates a new BlockStore
  BlockStore[V](
    recycle: initDeque[uint](size.int div 2),
    data: newSeq[V](size),
    liveness: newSeq[uint64](size.wordsFor),
  )

proc isDone*(iter: BlockIter): bool {.inline.} =
  iter.isDone

func len*[V](blockstore: var BlockStore[V]): Natural =
  ## Returns the length of this blockstore
  blockstore.len

proc isAlive[V](store: BlockStoreObj[V], idx: uint): bool {.inline.} =
  ## Whether the value at an index is live
  (store.liveness[idx.wordOf] and idx.bitOf) != 0

proc reserve*[V](blockstore: var BlockStore[V]): Entry[V] =
  ## Reserves a slot for a value
  var index: uint

  block indexBreak:
    if blockstore.hasRecycledValues:
      if blockstore.recycle.len > 0:
        index = blockstore.recycle.popFirst()
        break indexBreak
      blockstore.hasRecycledValues = false
    index = blockstore.nextId
    blockstore.nextId += 1

  if unlikely(index >= blockstore.data.len.uint):
    raise newException(IndexDefect, "Storage capacity exceeded: " & $index)

  blockstore.len += 1
  return Entry[V](store: addr blockstore[], idx: index)

proc index*[V](entry: Entry[V]): uint {.inline.} = ## Returns the index of an entry
  entry.idx

template value*[V](entry: Entry[V]): var V = ## Returns the value of an entry
  entry.store.data[entry.idx]

proc commit*[V](entry: Entry[V]) {.inline.} =
  ## Marks that an entry is ready to be used
  entry.store.liveness[entry.idx.wordOf] =
    entry.store.liveness[entry.idx.wordOf] or entry.idx.bitOf

template set*[V](entry: Entry[V], newValue: V) =
  ## Sets a value on an entry
  entry.value = newValue
  entry.commit

template push*[V](store: var BlockStore[V], newValue: V): uint =
  ## Adds a value and returns an index to it
  var entry = store.reserve
  entry.set(newValue)
  entry.index

proc del*[V](store: var BlockStore[V], idx: uint): V =
  ## Deletes a field
  if unlikely(idx >= store.data.len.uint):
    raise newException(IndexDefect, "index out of bounds: " & $idx)
  if store[].isAlive(idx):
    store.liveness[idx.wordOf] = store.liveness[idx.wordOf] and not idx.bitOf
    store.len -= 1
    result = move(store.data[idx])
    store.recycle.addLast(idx)
    store.hasRecycledValues = true

proc `[]`*[V](store: BlockStore[V], idx: uint): var V =
  ## Reads a field
  store.data[idx]

template `[]=`*[V](store: BlockStore[V], idx: uint, newValue: V) =
  ## Sets a new value for a key
  store.data[idx] = newValue

proc next*[V](store: var BlockStore[V], iter: var BlockIter): ptr V {.inline.} =
  ## Returns the next value in an iterator
  while true:
    if unlikely(store == nil or iter.index >= store.nextId):
      iter.isDone = true
      return nil
    let idx = iter.index
    iter.index = idx + 1
    if likely(store[].isAlive(idx)):
      return addr store.data[idx]

proc isAlive(liveness: ptr UncheckedArray[uint64], idx: uint): bool {.inline.} =
  ## Whether the slot at an index is filled, read straight from the bitmap
  (liveness[idx.wordOf] and idx.bitOf) != 0

proc wholeSpan*[V](store: var BlockStore[V]): BlockSpan =
  ## Returns every slot the store has handed out, filled or not. The count is fixed when
  ## the span is taken, so a walk sees the store as it stood when the walk began and
  ## values pushed part way through are left for the next one.
  ##
  ## Liveness is deliberately not baked in, because values can be deleted midway through a
  ## span being walked. It travels with the span so each slot can be confirmed as it is
  ## reached
  result.stride = uint(sizeof(V))

  if unlikely(store == nil) or store.nextId == 0:
    return

  result.base = addr store.data[0]
  result.liveness = cast[ptr UncheckedArray[uint64]](addr store.liveness[0])
  result.count = store.nextId

proc slots*(span: BlockSpan): uint {.inline.} =
  ## The number of slots this span covers, filled or not
  span.count

proc isEmpty*(span: BlockSpan): bool {.inline.} =
  ## Whether this span covers any slots at all
  span.count == 0

proc isAlive*(span: BlockSpan, idx: uint): bool {.inline.} =
  ## Whether the slot at an index is currently filled. Reads live state, not the state
  ## from when the span was taken
  assert(idx < span.count)
  span.liveness.isAlive(idx)

iterator addresses*[V](span: BlockSpan, kind: typedesc[V]): ptr V =
  ## Walks the filled slots in a span, yielding the address of each as a `ptr V`. `V` needs
  ## to fit in a slot, but does not have to fill it: a caller that only knows how a slot
  ## starts can walk it as that, then work out the rest of the slot from there.
  ##
  ## Liveness is confirmed as the walk goes rather than trusted from when the span was
  ## taken, so a caller is free to delete slots this walk has not reached yet. The bitmap
  ## word is shared by sixty four slots, so it stays in cache.
  ##
  ## This is named apart from `items` on purpose: `items` is late bound inside generic code,
  ## which would resolve it against whatever the instantiating module happens to import
  assert(
    span.isEmpty or uint(sizeof(V)) <= span.stride,
    "Slots in this span are too small to be read as " & $V,
  )
  # These are read out up front because the loop body below is free to call back into the
  # store the span came from, which stops the compiler from proving the span itself has not
  # moved under it. Left inline, `count` alone costs a reload per slot
  let liveness = span.liveness
  let stride = span.stride
  let count = span.count
  var address = cast[uint](span.base)
  for idx in 0'u ..< count:
    if likely(liveness.isAlive(idx)):
      yield cast[ptr V](address)
    address += stride

iterator items*[V](span: BlockSpan, kind: typedesc[V]): var V =
  ## Walks the filled slots in a span as the type they were stored as
  assert(span.isEmpty or uint(sizeof(V)) == span.stride, "Span is not a span of " & $V)
  for address in span.addresses(V):
    yield address[]

iterator items*[V](store: var BlockStore[V]): var V =
  ## Iterate through all values in this BlockStore
  var iter: BlockIter
  var value: ptr V
  while true:
    value = store.next(iter)
    if value == nil:
      break
    yield value[]
