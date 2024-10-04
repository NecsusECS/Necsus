import ringbuffer, options

type
    EntryData[V] = object
        idx: uint
        alive: bool
        value: V

    Entry*[V] = ptr EntryData[V]

    BlockStore*[V] = ref object
        ## Stores a block of packed values
        nextId: uint
        hasRecycledValues: bool
        recycle: RingBuffer[uint]
        data: seq[EntryData[V]]
        len: uint

    BlockIter* = object
        index: uint

proc newBlockStore*[V](size: SomeInteger): BlockStore[V] =
    ## Instantiates a new BlockStore
    BlockStore[V](recycle: newRingBuffer[uint](size), data: newSeq[EntryData[V]](size))

proc isFirst*(iter: BlockIter): bool = iter.index == 0

func len*[V](blockstore: var BlockStore[V]): uint = blockstore.len
    ## Returns the length of this blockstore

proc reserve*[V](blockstore: var BlockStore[V]): Entry[V] =
    ## Reserves a slot for a value
    var index: uint

    if blockstore.hasRecycledValues:
        let recycled = tryShift(blockstore.recycle)
        if isSome(recycled):
            index = unsafeGet(recycled)
        else:
            blockstore.hasRecycledValues = false
            index = blockstore.nextId
            blockstore.nextId += 1
    else:
        index = blockstore.nextId
        blockstore.nextId += 1

    blockstore.len += 1
    result = addr blockstore.data[index]
    result.idx = index

proc index*[V](entry: Entry[V]): uint {.inline} = entry.idx
    ## Returns the index of an entry

template value*[V](entry: Entry[V]): var V = entry.value
    ## Returns the value of an entry

proc commit*[V](entry: Entry[V]) {.inline.} =
    ## Marks that an entry is ready to be used
    entry.alive = true

proc set*[V](entry: Entry[V], value: sink V) =
    ## Sets a value on an entry
    entry.value = value
    entry.commit

proc push*[V](store: var BlockStore[V], value: sink V): uint =
    ## Adds a value and returns an index to it
    var entry = store.reserve
    entry.set(value)
    return entry.index

proc del*[V](store: var BlockStore[V], idx: uint): V =
    ## Deletes a field
    if store.data[idx].alive:
        store.data[idx].alive = false
        store.len -= 1
        let deleted = move(store.data[idx])
        result = deleted.value
        store.recycle.tryPush(idx)
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
        if unlikely(iter.index >= store.nextId):
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
