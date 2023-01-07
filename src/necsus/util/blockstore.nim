import atomics, ringbuffer, arrayblock, options

type
    Entry[V] = object
        alive: Atomic[bool]
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

proc reserve*[V](blockstore: var BlockStore[V], construct: proc (i: uint, value: var V)): uint {.inline.} =
    ## Adds a value and returns an index to it
    let recycled = tryShift(blockstore.recycle)
    let index = if isSome(recycled): unsafeGet(recycled) else: fetchAdd(blockstore.nextId, 1)
    construct(index, blockstore.data[index].value)
    store(blockstore.data[index].alive, true)
    index

proc push*[V](store: var BlockStore[V], value: sink V): uint =
    ## Adds a value and returns an index to it
    return store.reserve do (i: uint, storage: var V) -> void:
        storage = value

proc del*[V](store: var BlockStore[V], idx: uint) =
    ## Deletes a field
    var falsey = true
    if store.data[idx].alive.compareExchange(falsey, false):
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
        if entry.alive.load:
            yield entry.value
