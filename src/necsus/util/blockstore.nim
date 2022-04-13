import atomics, ringbuffer, arrayblock, options

type
    Entry[V] = object
        deleted: Atomic[bool]
        value: V

    BlockStore*[V] = object
        ## Stores a block of packed values
        nextId: Atomic[uint]
        recycle: RingBuffer[uint]
        data: ArrayBlock[Entry[V]]

proc newBlockStore*[V](size: SomeInteger): BlockStore[V] =
    ## Instantiates a new BlockStore
    result.recycle = newRingBuffer[uint](size)
    result.data = newArrayBlock[Entry[V]](size)

proc push*[V](store: var BlockStore[V], value: sink V): uint =
    ## Adds a value and returns an index to it
    let recycled = store.recycle.tryShift()
    result = if recycled.isSome: recycled.unsafeGet else: store.nextId.fetchAdd(1)
    store.data[result] = Entry[V](value: value)

proc del*[V](store: var BlockStore[V], idx: uint) =
    ## Deletes a field
    var falsey = false
    if store.data[idx].deleted.compareExchange(falsey, true):
        discard store.recycle.tryPush(idx)

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
        if not entry.deleted.load:
            yield entry.value
