import math, options

type
    RingBuffer*[T] {.byref.} = object
        ## Ring buffer instance
        head, tail: uint ## Head is the index of the front of the ringbuffer, tail is the index of the back
        mask: uint
            ## The queue is memory-bounded. Instead of saving the
            ## size of the queue we save the bit mask: assuming
            ## a size power of 2 N, we can compute X % N as
            ## X & mask for any integer. (where & is faster than %).
        data: seq[T]
        size: uint ## The overall capacity of the ringbuffer

proc newRingBuffer*[T](minimumSize: SomeInteger): RingBuffer[T] =
    let size = nextPowerOfTwo(minimumSize.int).uint
    return RingBuffer[T](
        size: size - 1,
        data: newSeq[T](size),

        # Assuming a size power of 2 N, we can compute X % N as X & mask for any integer. (where & is faster than %).
        mask: size - 1
    )

proc `$`*[T](ring: RingBuffer[T]): string =
    result.add("[")
    var isFirst = true
    for i in ring.head..<ring.tail:
        if isFirst:
            isFirst = false
        else:
            result.add(", ")
        result.add($ring.data[i and ring.mask])
    result.add("]")

proc capacity*[T](ring: RingBuffer[T]): uint =
    ## Return the capacity of this buffer.
    # We allocated a queue of size N, and by definition the mask is N-1.  # Now, the queue always leaves 1
    # slot empty between the head  and the tail to differentiate a full queue from an empty queue
    # so the capacity is also N-1
    ring.size

proc tryPush*[T](ring: var RingBuffer[T], value: sink T) =
    ## Pushes a value onto the ring, returning true if it was a success
    if ring.size + ring.head - ring.tail <= 0:
        ring.head += 1

    let idx = ring.tail and ring.mask
    ring.data[idx] = value
    ring.tail = ring.tail + 1

proc tryShift*[T](ring: var RingBuffer[T]): Option[T] =
    if ring.tail - ring.head > 0:
        let idx = ring.head and ring.mask
        result = some(ring.data[idx])
        ring.head = ring.head + 1

proc drain*[T](ring: var RingBuffer[T]): seq[T] =
    ## Removes all values from this buffer and puts them in a sequence
    while true:
        let value = ring.tryShift()
        if value.isSome:
            result.add(value.get)
        else:
            break

proc isEmpty*[T](ring: RingBuffer[T]): bool =
    ## Return whether this ring buffer is void of any values
    (ring.tail - ring.head) == 0
