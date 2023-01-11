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

proc newBlockStore*[V](size: SomeInteger): BlockStore[V] =
    ## Instantiates a new BlockStore
    result.recycle = newRingBuffer[uint](size)
    result.data = newArrayBlock[EntryData[V]](size)

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

    result = addr blockstore.data[index]
    result.idx = index

proc index*[V](entry: Entry[V]): uint {.inline} = entry.idx
    ## Returns the index of an entry

proc value*[V](entry: Entry[V]): var V {.inline.} = entry.value
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

proc `[]`*[V](store: BlockStore[V], idx: uint): lent V =
    ## Reads a field
    store.data[idx].value

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
