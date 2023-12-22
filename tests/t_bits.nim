import unittest, necsus/util/bits, sequtils, sets

suite "Bits":

    test "Bit cardinality":
        var bits = Bits()
        check(bits.card == 0)

        bits.incl(4)
        check(bits.card == 1)

        bits.incl(500)
        check(bits.card == 2)

        bits.incl(500)
        check(bits.card == 2)

    test "Bit equality":
        var bits1 = Bits()
        var bits2 = Bits()

        check(bits1 == bits2)
        check(bits2 == bits1)

        bits1.incl(1)
        check(bits1 != bits2)
        check(bits2 != bits1)

        bits2.incl(1)
        check(bits1 == bits2)
        check(bits2 == bits1)

        bits1.incl(500)
        check(bits1 != bits2)
        check(bits2 != bits1)

        bits2.incl(500)
        check(bits1 == bits2)
        check(bits2 == bits1)

    test "Bit addition":
        let bits1 = newBits(1)
        let bits2 = newBits(500)

        check(bits1 + bits2 == newBits(1, 500))
        check((bits1 + bits2).card == 2)

    test "Bit subtraction":
        check(newBits(1, 500) - newBits(500) == newBits(1))
        check(newBits(1, 500) - newBits(1) == newBits(500))

    test "Bit strict subset":
        let bits1 = newBits(1, 500)
        let bits2 = newBits(500)
        let bits3 = newBits(1)

        check(bits2 < bits1)
        check(bits3 < bits1)
        check(not (bits1 < bits2))
        check(not (bits1 < bits3))
        check(not (bits1 < bits1))

    test "Bit subset":
        let bits1 = newBits(1, 4)
        let bits2 = newBits(4)
        let bits3 = newBits(1)

        check(bits2 <= bits1)
        check(bits3 <= bits1)
        check(bits1 <= bits1)
        check(not (bits1 <= bits2))
        check(not (bits1 <= bits3))

    test "Bit anyIntersect":
        check(newBits(1, 2, 3).anyIntersect(newBits(3, 4, 5)))
        check(newBits(1, 200, 300).anyIntersect(newBits(300, 400, 500)))
        check(not newBits(1, 2, 3).anyIntersect(newBits(4, 5, 6)))
        check(not newBits(1, 200, 300).anyIntersect(newBits(400, 500, 600)))

    test "Bit iteration":
        var bits = Bits()
        check(bits.toSeq.len == 0)

        bits.incl(2)
        check(bits.toSeq == @[ 2'u16 ])

        bits.incl(200)
        check(bits.toSeq == @[ 2'u16, 200 ])

    test "Bit to string":
        var bits = Bits()
        check($bits == "{}")

        bits.incl(2)
        check($bits == "{2}")

        bits.incl(500)
        check($bits == "{2, 500}")

    test "Storing bits in sets":
        var storage = initHashSet[Bits]()

        check(newBits(1, 2, 3) notin storage)

        storage.incl(newBits(1, 2, 3))
        check(newBits(1, 2, 3) in storage)
        check(storage.len == 1)

        storage.incl(newBits(1, 2, 3))
        check(newBits(1, 2, 3) in storage)
        check(storage.len == 1)