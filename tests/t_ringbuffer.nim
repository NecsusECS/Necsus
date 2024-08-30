import unittest, necsus/util/ringbuffer, options

suite "RingBuffer":

    test "tryPush and tryShift":
        var q = newRingBuffer[int](8)

        q.tryPush(123)
        q.tryPush(456)
        q.tryPush(789)

        check(q.tryShift() == some(123))
        check(q.tryShift() == some(456))
        check(q.tryShift() == some(789))

    test "Draining":
        var q = newRingBuffer[int](8)
        q.tryPush(123)
        q.tryPush(456)
        q.tryPush(789)
        check(q.drain() == @[ 123, 456, 789 ])

    test "Pushing onto a full queue":
        var q = newRingBuffer[int](4)
        check(q.capacity == 3)

        q.tryPush(1)
        q.tryPush(2)
        q.tryPush(3)
        q.tryPush(4)
        q.tryPush(5)

        check(q.drain() == @[ 3, 4, 5 ])

    test "Wrapping around":
        var q = newRingBuffer[int](8)

        for i in 0..<7:
            q.tryPush(i)

        for i in 7..<100:
            require(q.tryShift() == some(i - 7))
            q.tryPush(i)

    test "Popping from an empty ring":
        var q = newRingBuffer[int](8)
        check(q.tryShift().isNone)

    test "Stringify":
        var q = newRingBuffer[int](8)
        check($q == "[]")

        q.tryPush(123)
        check($q == "[123]")

        q.tryPush(456)
        check($q == "[123, 456]")

        q.tryPush(789)
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

        q.tryPush(123)
        check(not q.isEmpty)

    test "Allow ring buffer sizes that aren't a power of 2":
        var q = newRingBuffer[int](200)
        check(q.capacity == 255)
