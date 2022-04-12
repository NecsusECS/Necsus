##
## Multi Producer/Multi Consumer Ring Buffer
##
## This is a lock free structure that allows multiple threads to push (produce) and pop (consume) data
## in a FIFO way.
##
## The queue is bounded with a size of N where N must be a power of 2. The implementation however
## allows to store only a maximum of N-1 elements.
##
## References:
## * https://book-of-gehn.github.io/articles/2020/04/28/Lock-Free-Queue-Part-II.html
## * https://github.com/eldipa/loki
##

import atomics, math, options, arrayblock

type
    RingBuffer*[T] {.byref.} = object
        ## Ring buffer instance

        prodHead, prodTail: Atomic[uint]
            ## On push (enqueue), the thread works as a producer:
            ##  - it produces a new datum moving the head forward
            ##  - and the datum enables the readers (consumers) to read it
            ##    moving the tail forward to (yes, the push moves the tail too).

        prodMask: uint
            ## The queue is memory-bounded. Instead of saving the
            ## size of the queue we save the bit mask: assuming
            ## a size power of 2 N, we can compute X % N as
            ## X & mask for any integer. (where & is faster than %).

        pad1: array[13, uint]
            ## Pad between producer and consumer attributes. This avoids the "false sharing" problem: when we modify
            ## and attribute, the whole L1/L2 cache line needs to be updated in all the cores. If at the same time other
            ## thread is accessing to the other attributes a conflict will arise. The CPU will know how to fix it but it
            ## is going to have a penalty.

        consHead, consTail: Atomic[uint]
            ##  On pop (dequeue), the thread works as a consumer:
            ##   - it consumes a datum moving the tail forward
            ##   - and moves the head forward too, let the writers (producers)
            ##     know that there is a new free slot there.

        consMask: uint
            ## Why again the mask? Having two copies of the mask, each next
            ## to the respective head/tail ensures that the head, the tail
            ## and the mask of the producer will be in its own L2 cache line
            ## avoiding "false sharings"

        pad2: array[13, uint]
            ## More padding to prevent false sharing

        data: ArrayBlock[T]

        size: uint
            ## The length of data being stored

proc newRingBuffer*[T](minimumSize: SomeInteger): RingBuffer[T] =
    let size = nextPowerOfTwo(minimumSize.int).uint
    result.size = size - 1
    result.data = newArrayBlock[T](size)

    # Assuming a size power of 2 N, we can compute X % N as X & mask for any integer. (where & is faster than %).
    result.prodMask = size - 1
    result.consMask = size - 1

proc `$`*[T](ring: var RingBuffer[T]): string =
    result.add("[")
    var isFirst = true
    for i in ring.consHead.load..<ring.prodHead.load:
        if isFirst:
            isFirst = false
        else:
            result.add(", ")
        result.add($ring.data[i and ring.prodMask])
    result.add("]")

proc capacity*[T](ring: RingBuffer[T]): uint =
    ## Return the capacity of this buffer.
    # We allocated a queue of size N, and by definition the mask is N-1.  # Now, the queue always leaves 1
    # slot empty between the head  and the tail to differentiate a full queue from an empty queue
    # so the capacity is also N-1
    ring.size

proc tryPush*[T](ring: var RingBuffer[T], value: sink T): bool =
    ## Pushes a value onto the ring, returning true if it was a success
    while true:
        block retry:
            var oldProdHead = ring.prodHead.load(moRelaxed)

            fence(moAcquire)

            ## Step 1: Make sure there is capacity to store this value
            let available = ring.capacity + ring.consTail.load(moAcquire) - oldProdHead
            if available <= 0:
                return false

            # Step 2: Reserve a slot where we can store the new value
            let newProdHead = oldProdHead + 1
            if not ring.prodHead.compareExchange(oldProdHead, newProdHead, moRelaxed, moRelaxed):
                break retry

            # Step 3: Slot reserved, store the value
            let idx = oldProdHead and ring.prodMask
            ring.data[idx] = value

            # Step 4: Update the head to announce the new value
            while not ring.prodTail.compareExchange(oldProdHead, newProdHead, moRelease):
                discard

            return true

proc tryShift*[T](ring: var RingBuffer[T]): Option[T] =
    ## Shifts a value from the ring
    block done:
        while true:
            block retry:
                var oldConsHead = ring.consHead.load(moRelaxed)

                fence(moAcquire)

                # Step 1: Make sure there is something to pop
                let available = ring.prodTail.load(moAcquire) - oldConsHead
                if available <= 0:
                    return none(T)

                # Step 2: Request a slot to return
                let newConsHead = old_cons_head + 1
                if not ring.consHead.compareExchange(oldConsHead, newConsHead, moRelaxed, moRelaxed):
                    break retry

                # Step 3: Copy over the resulting data
                let idx = oldConsHead and ring.consMask
                result = some(ring.data[idx])

                # Step 4: Update the tail to announce the removed value
                while not ring.consTail.compareExchange(oldConsHead, newConsHead, moRelease):
                    discard

                break done

proc drain*[T](ring: var RingBuffer[T]): seq[T] =
    ## Removes all values from this buffer and puts them in a sequence
    while true:
        let value = ring.tryShift()
        if value.isSome:
            result.add(value.get)
        else:
            break

proc isEmpty*[T](ring: var RingBuffer[T]): bool =
    ## Return whether this ring buffer is void of any values
    (ring.prodHead.load - ring.consHead.load) == 0
