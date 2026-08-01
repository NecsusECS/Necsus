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

  test "Bit contins":
    let bits = newBits(1, 2, 3, 4, 500)
    check(1 in bits)
    check(4 in bits)
    check(500 in bits)
    check(5 notin bits)
    check(5000 notin bits)

  test "Bit addition":
    let bits1 = newBits(1)
    let bits2 = newBits(500)

    check(bits1 + bits2 == newBits(1, 500))
    check((bits1 + bits2).card == 2)

  test "In-place Bit addition":
    var bits = newBits(1, 5, 10, 500)
    bits += newBits(5, 6, 500, 700)

    check(bits == newBits(1, 5, 6, 10, 500, 700))
    check(bits.card == 6)

  test "Bit subtraction":
    check(newBits(1, 500) - newBits(500) == newBits(1))
    check(newBits(1, 500) - newBits(1) == newBits(500))
    check(newBits(1, 2) - newBits(2) == newBits(1))
    check((newBits(1, 2) - newBits(2)).card == 1)
    check(newBits(1) - newBits(500) == newBits(1))

  test "Subtracting everything leaves a set indistinguishable from an empty one":
    for emptied in [
      newBits(1, 500) - newBits(1, 500),
      newBits(500) - newBits(500),
      newBits(1) - newBits(1, 2, 500),
    ]:
      check(emptied.isEmpty)
      check(emptied.card == 0)
      check(emptied == Bits())
      check(Bits() == emptied)
      check(emptied.hash == Bits().hash)
      check(emptied.toSeq.len == 0)

    # Which means an emptied set and a never populated one are the same key
    var storage = initHashSet[Bits]()
    storage.incl(newBits(1, 500) - newBits(1, 500))
    storage.incl(Bits())
    check(storage.len == 1)

  test "Bit emptiness":
    check(Bits().isEmpty)
    check(newBits().isEmpty)
    check(not newBits(0).isEmpty)
    check(not newBits(500).isEmpty)

  test "Bit combining":
    # `remove` applies after `attach`, so an attached bit can be taken straight back out
    check(combine(newBits(1, 2), newBits(3), newBits(1)) == newBits(2, 3))
    check(combine(newBits(1), newBits(2), newBits(2)) == newBits(1))

    # Either half is optional
    check(combine(newBits(1, 2), nil, nil) == newBits(1, 2))
    check(combine(newBits(1, 2), newBits(3), nil) == newBits(1, 2, 3))
    check(combine(newBits(1, 2), nil, newBits(1)) == newBits(2))

    # Operands reaching past each other in either direction
    check(combine(newBits(1), newBits(500), nil) == newBits(1, 500))
    check(combine(newBits(1), nil, newBits(500)) == newBits(1))
    check(combine(newBits(1, 500), newBits(2), newBits(500)) == newBits(1, 2))

    # And a result that empties out is still canonical
    let emptied = combine(newBits(1), nil, newBits(1))
    check(emptied.isEmpty)
    check(emptied == Bits())
    check(emptied.hash == Bits().hash)

  test "Bit subset of a union":
    check(newBits(1, 2).isSubsetOfUnion(newBits(1), newBits(2)))
    check(newBits(1, 2).isSubsetOfUnion(newBits(1, 2), newBits()))
    check(newBits(1, 2).isSubsetOfUnion(newBits(), newBits(1, 2)))
    check(newBits().isSubsetOfUnion(newBits(), newBits()))
    check(not newBits(1, 2, 3).isSubsetOfUnion(newBits(1), newBits(2)))

    # Where the subset reaches into buckets only one side of the union has
    check(newBits(1, 500).isSubsetOfUnion(newBits(1), newBits(500)))
    check(newBits(1, 500).isSubsetOfUnion(newBits(500), newBits(1)))
    check(not newBits(500).isSubsetOfUnion(newBits(1), newBits(2)))

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
    check(not (newBits(1, 500) <= newBits(1, 2, 3)))
    check(newBits(1, 2, 3) <= newBits(1, 2, 3, 500))

    check(not (bits2 > bits1))
    check(not (bits3 > bits1))
    check(not (bits1 > bits1))
    check(bits1 > bits2)
    check(bits1 > bits3)

  test "Bit intersection":
    check(newBits(1, 2, 3).intersect(newBits(2, 3, 4)) == newBits(2, 3))
    check(newBits(1, 500).intersect(newBits(500, 700)) == newBits(500))

    # Where one side reaches past the other, and where nothing is shared at all
    check(newBits(1, 500).intersect(newBits(1)) == newBits(1))
    check(newBits(1).intersect(newBits(1, 500)) == newBits(1))
    check(newBits(1, 2).intersect(newBits(500)).isEmpty)
    check(newBits(1, 2).intersect(Bits()).isEmpty)

    # An intersection that comes out empty is still canonical
    let emptied = newBits(1, 500).intersect(newBits(2))
    check(emptied == Bits())
    check(emptied.hash == Bits().hash)

  test "What a filter can tell apart":
    check(
      newFilter(mustContain = newBits(1, 5), mustExclude = newBits(4, 500)).mentioned ==
        newBits(1, 4, 5, 500)
    )
    check(newFilter(mustContain = newBits(), mustExclude = newBits()).mentioned.isEmpty)

    var missing: BitsFilter = nil
    check(missing.mentioned.isEmpty)

  test "Bit anyIntersect":
    check(newBits(1, 2, 3).anyIntersect(newBits(3, 4, 5)))
    check(newBits(1, 200, 300).anyIntersect(newBits(300, 400, 500)))
    check(not newBits(1, 2, 3).anyIntersect(newBits(4, 5, 6)))
    check(not newBits(1, 200, 300).anyIntersect(newBits(400, 500, 600)))

  test "Bit iteration":
    var bits = Bits()
    check(bits.toSeq.len == 0)

    bits.incl(2)
    check(bits.toSeq == @[2'u16])

    bits.incl(200)
    check(bits.toSeq == @[2'u16, 200])

  test "Bit iteration across word boundaries":
    check(newBits(0).toSeq == @[0'u16])
    check(newBits(63).toSeq == @[63'u16])
    check(newBits(64).toSeq == @[64'u16])
    check(newBits(0, 63, 64, 127, 128).toSeq == @[0'u16, 63, 64, 127, 128])

    # A fully populated word, to make sure nothing is skipped or repeated
    var full = Bits()
    for i in 0'u16 .. 64'u16:
      full.incl(i)
    check(full.toSeq == (0'u16 .. 64'u16).toSeq)
    check(full.card == 65)

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

  test "Filters":
    let filter = newFilter(mustContain = newBits(1, 5, 40), mustExclude = newBits(4))

    check(filter.matches(all = newBits(1, 5, 40)))
    check(filter.matches(all = newBits(1, 5, 40, 80, 100)))
    check(not filter.matches(all = newBits(1, 100, 400)))
    check(not filter.matches(all = newBits(1, 5)))
    check(not filter.matches(all = newBits(1, 4, 5, 40, 50)))

    check(
      newFilter(mustContain = newBits(), mustExclude = newBits(40)).matches(
        all = newBits(1, 2, 3)
      )
    )

    check(filter.matches(all = newBits(1, 5, 40), optional = newBits(5, 40)))
    check(filter.matches(all = newBits(1, 4, 5, 40), optional = newBits(4)))

    # An exclusion reaching past the end of the set being tested excludes nothing
    check(
      newFilter(mustContain = newBits(), mustExclude = newBits(500)).matches(newBits(1))
    )
    check(
      not newFilter(mustContain = newBits(), mustExclude = newBits(500)).matches(
        newBits(1, 500)
      )
    )

    # As does a requirement, except that it can never be satisfied
    check(
      not newFilter(mustContain = newBits(500), mustExclude = newBits()).matches(
        newBits(1)
      )
    )

  test "Filters that accept everything":
    var missing: BitsFilter = nil
    check(missing.acceptsAll)
    check(newFilter(mustContain = newBits(), mustExclude = newBits()).acceptsAll)
    check(not newFilter(mustContain = newBits(1), mustExclude = newBits()).acceptsAll)
    check(not newFilter(mustContain = newBits(), mustExclude = newBits(1)).acceptsAll)

  test "Listing what a filter requires":
    check(
      newFilter(mustContain = newBits(1, 5, 40), mustExclude = newBits(4)).required.toSeq ==
        @[1'u16, 5, 40]
    )
    check(
      newFilter(mustContain = newBits(), mustExclude = newBits(4)).required.toSeq.len ==
        0
    )

  test "Dropping a component a filter requires":
    let filter = newFilter(mustContain = newBits(1, 5), mustExclude = newBits(4))
    let dropped = filter.withoutRequired(1)

    check(dropped.required.toSeq == @[5'u16])

    # The dropped requirement is no longer asked for, but everything else still is
    check(dropped.matches(newBits(5)))
    check(dropped.matches(newBits(1, 5)))
    check(not dropped.matches(newBits(1)))
    check(not dropped.matches(newBits(4, 5)))

    # The original is left alone
    check(not filter.matches(newBits(5)))

    # Dropping the only requirement leaves a filter that still excludes
    check(
      newFilter(mustContain = newBits(1), mustExclude = newBits())
        .withoutRequired(1).acceptsAll
    )
    check(
      not newFilter(mustContain = newBits(1), mustExclude = newBits(4))
        .withoutRequired(1).acceptsAll
    )
