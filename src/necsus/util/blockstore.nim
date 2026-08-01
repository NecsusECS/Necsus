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

proc isFirst*(iter: BlockIter): bool =
  iter.index == 0

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

iterator items*[V](store: var BlockStore[V]): var V =
  ## Iterate through all values in this BlockStore
  var iter: BlockIter
  var value: ptr V
  while true:
    value = store.next(iter)
    if value == nil:
      break
    yield value[]
