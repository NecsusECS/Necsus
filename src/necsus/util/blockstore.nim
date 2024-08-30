import threads, ringbuffer, options

type
    EntryData[V] = object
        idx: uint
        alive: Atomic[bool]
        value: V

    Entry*[V] = ptr EntryData[V]

    BlockStore*[V] = ref object
        ## Stores a block of packed values
        nextId: Atomic[uint]
        hasRecycledValues: bool
        recycle: RingBuffer[uint]
        data: seq[EntryData[V]]
        len: Atomic[uint]

    BlockIter* {.byref.} = object
        max, index: uint

proc newBlockStore*[V](size: SomeInteger): BlockStore[V] =
    ## Instantiates a new BlockStore
    BlockStore[V](recycle: newRingBuffer[uint](size), data: newSeq[EntryData[V]](size))

proc isFirst*(iter: BlockIter): bool = iter.index == 0

func len*[V](blockstore: var BlockStore[V]): uint = blockstore.len.load
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
            index = fetchAdd(blockstore.nextId, 1)
    else:
        index = fetchAdd(blockstore.nextId, 1)

    blockstore.len.atomicInc(1)
    result = addr blockstore.data[index]
    result.idx = index

proc index*[V](entry: Entry[V]): uint {.inline} = entry.idx
    ## Returns the index of an entry

template value*[V](entry: Entry[V]): var V = entry.value
    ## Returns the value of an entry

proc commit*[V](entry: Entry[V]) {.inline.} =
    ## Marks that an entry is ready to be used
    store(entry.alive, true)

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
    var falsey = true
    if store.data[idx].alive.compareExchange(falsey, false):
        store.len.atomicDec(1)
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

proc next*[V](store: var BlockStore[V], iter: var BlockIter): ptr V =
    ## Returns the next value in an iterator
    if iter.max == 0:
        iter.max = store.nextId.load

    if iter.index >= iter.max:
        return nil
    elif store.data[iter.index].alive.load:
        iter.index += 1
        return addr store.data[iter.index - 1].value
    else:
        iter.index += 1
        return store.next(iter)

iterator items*[V](store: var BlockStore[V]): var V =
    ## Iterate through all values in this BlockStore
    var iter: BlockIter
    var value: ptr V
    while true:
        value = store.next(iter)
        if value == nil:
            break
        yield value[]
