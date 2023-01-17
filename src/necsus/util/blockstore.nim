import atomics, ringbuffer, arrayblock, options

type
    EntryData[V] = object
        idx: uint
        alive: Atomic[bool]
        value: V

    Entry*[V] = ptr EntryData[V]

    BlockStore*[V] = object
        ## Stores a block of packed values
        nextId: Atomic[uint]
        hasRecycledValues: bool
        recycle: RingBuffer[uint]
        data: ArrayBlock[EntryData[V]]
        len: Atomic[uint]

proc newBlockStore*[V](size: SomeInteger): BlockStore[V] =
    ## Instantiates a new BlockStore
    result.recycle = newRingBuffer[uint](size)
    result.data = newArrayBlock[EntryData[V]](size)

proc len*[V](blockstore: var BlockStore[V]): uint = blockstore.len.load
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

proc del*[V](store: var BlockStore[V], idx: uint) =
    ## Deletes a field
    var falsey = true
    if store.data[idx].alive.compareExchange(falsey, false):
        discard store.recycle.tryPush(idx)
        store.hasRecycledValues = true
    store.len.atomicDec(1)

proc `[]`*[V](store: BlockStore[V], idx: uint): var V =
    ## Reads a field
    store.data[idx].value

template `[]=`*[V](store: BlockStore[V], idx: uint, newValue: V) =
    ## Sets a new value for a key
    store.data[idx].value = newValue

iterator items*[V](store: var BlockStore[V]): var V =
    ## Iterate through all values in this BlockStore
    let upper = store.nextId.load
    var accum = 0u
    for entry in items(store.data):
        accum += 1
        if accum > upper:
            break
        if entry.alive.load:
            yield entry.value
