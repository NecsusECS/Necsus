import std/[deques, options]

type
  EntryData[V] = object
    idx: uint
    alive: bool
    value: V

  Entry*[V] = ptr EntryData[V]

  BlockStore*[V] = ref object ## Stores a block of packed values
    nextId: uint
    hasRecycledValues: bool
    recycle: Deque[uint]
    data: seq[EntryData[V]]
    len: uint

  BlockIter* = object
    index: uint
    isDone: bool

proc newBlockStore*[V](size: SomeInteger): BlockStore[V] =
  ## Instantiates a new BlockStore
  BlockStore[V](
    recycle: initDeque[uint](size.int div 2), data: newSeq[EntryData[V]](size)
  )

proc isFirst*(iter: BlockIter): bool =
  iter.index == 0

proc isDone*(iter: BlockIter): bool {.inline.} =
  iter.isDone

func len*[V](blockstore: var BlockStore[V]): uint =
  ## Returns the length of this blockstore
  blockstore.len

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
  result = addr blockstore.data[index]
  result.idx = index

proc index*[V](entry: Entry[V]): uint {.inline.} = ## Returns the index of an entry
  entry.idx

template value*[V](entry: Entry[V]): var V = ## Returns the value of an entry
  entry.value

proc commit*[V](entry: Entry[V]) {.inline.} =
  ## Marks that an entry is ready to be used
  entry.alive = true

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
  if store.data[idx].alive:
    store.data[idx].alive = false
    store.len -= 1
    let deleted = move(store.data[idx])
    result = deleted.value
    store.recycle.addLast(idx)
    store.hasRecycledValues = true

proc `[]`*[V](store: BlockStore[V], idx: uint): var V =
  ## Reads a field
  store.data[idx].value

template `[]=`*[V](store: BlockStore[V], idx: uint, newValue: V) =
  ## Sets a new value for a key
  store.data[idx].value = newValue

proc next*[V](store: var BlockStore[V], iter: var BlockIter): ptr V {.inline.} =
  ## Returns the next value in an iterator
  while true:
    if unlikely(store == nil or iter.index >= store.nextId):
      iter.isDone = true
      return nil
    elif likely(store.data[iter.index].alive):
      iter.index += 1
      return addr store.data[iter.index - 1].value
    else:
      iter.index += 1

iterator items*[V](store: var BlockStore[V]): var V =
  ## Iterate through all values in this BlockStore
  var iter: BlockIter
  var value: ptr V
  while true:
    value = store.next(iter)
    if value == nil:
      break
    yield value[]
