import unittest, necsus/util/ringbuffer, options, threadpool, std/sharedlist, sequtils, algorithm, random, atomics

suite "RingBuffer":

    test "tryPush and tryShift":
        var q = newRingBuffer[int](8)

        check(q.tryPush(123))
        check(q.tryPush(456))
        check(q.tryPush(789))

        check(q.tryShift() == some(123))
        check(q.tryShift() == some(456))
        check(q.tryShift() == some(789))

    test "Draining":
        var q = newRingBuffer[int](8)
        check(q.tryPush(123))
        check(q.tryPush(456))
        check(q.tryPush(789))
        check(q.drain() == @[ 123, 456, 789 ])

    test "Pushing onto a full queue":
        var q = newRingBuffer[int](4)
        check(q.capacity == 3)

        check(q.tryPush(1))
        check(q.tryPush(2))
        check(q.tryPush(3))
        check(not q.tryPush(4))
        check(not q.tryPush(5))

    test "Wrapping around":
        var q = newRingBuffer[int](8)

        for i in 0..<7:
            check(q.tryPush(i))

        for i in 7..<100:
            require(q.tryShift() == some(i - 7))
            require(q.tryPush(i))

    test "Popping from an empty ring":
        var q = newRingBuffer[int](8)
        check(q.tryShift().isNone)

    test "Stringify":
        var q = newRingBuffer[int](8)
        check($q == "[]")

        check q.tryPush(123)
        check($q == "[123]")

        check q.tryPush(456)
        check($q == "[123, 456]")

        check q.tryPush(789)
        check($q == "[123, 456, 789]")

        discard q.tryShift
        check($q == "[456, 789]")

        discard q.tryShift
        check($q == "[789]")

        discard q.tryShift
        check($q == "[]")

    test "isEmpty":
        var q = newRingBuffer[int](8)
        check(q.isEmpty)

        discard q.tryPush(123)
        check(not q.isEmpty)

    test "Allow ring buffer sizes that aren't a power of 2":
        var q = newRingBuffer[int](200)
        check(q.capacity == 255)

    test "Multi-threaded push and shift":
        var q = newRingBuffer[int](2048)

        proc pushIt(value: int) {.gcsafe.} =
            require(q.tryPush(value))

        for i in 0..<2000:
            spawn pushIt(i)

        var results: SharedList[int]
        results.init

        proc shiftIt() =
            results.add(q.tryShift().get)

        for i in 0..<2000:
            spawn shiftIt()

        sync()

        check(results.toSeq.sorted == toSeq(0..<2000))

    for i in 0..10:
        test "Random push and pop #" & $i:
            var q = newRingBuffer[uint64](2048)
            var length: Atomic[int]

            proc act(randomInt: uint64) {.gcsafe.} =
                if randomInt mod 2 == 0:
                    if q.tryPush(randomInt):
                        length += 1
                else:
                    if q.tryShift().isSome:
                        length -= 1

            var rand = initRand(i)
            for _ in 0..<2000:
                spawn act(rand.next())

            sync()

            check(q.drain.len == length.load)
