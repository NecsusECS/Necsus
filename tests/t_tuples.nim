import unittest, necsus/runtime/tuples

type
  A = string
  B = int
  C = float
  D = bool
  E = object
  F = seq[int]

  X = object
  Y = object
  Z = object

  ACE = (A, C, E)
  BDF = (B, D, F)
  ACEBDF = (A, C, E, B, D, F)

  AB = (A, B)
  WithCD = extend(AB, (C, D))
  WithEF = extend(WithCD, (E, F))

  Wrapped*[T: tuple] = object
    value: extend((A, B), T)

let ace: ACE = ("foo", 3.14, E())
let bdf: BDF = (123, true, @[1])
let abcdef: ACEBDF = ("foo", 3.14, E(), 123, true, @[1])

suite "Tuple tools":
  test "Tuples should be extendable":
    check(extend(ACE, BDF) is ACEBDF)
    check(extend((A, C, E), BDF) is ACEBDF)
    check(extend(ACE, (B, D, F)) is ACEBDF)
    check(extend((A, C, E), (B, D, F)) is ACEBDF)
    check(extend(AB, (C, D)).extend((E, F)) is (A, B, C, D, E, F))

  test "Tuples with labels should be extendable":
    check(extend(tuple[a: A, c: C, e: E], BDF) is ACEBDF)
    check(extend(ACE, tuple[b: B, d: D, f: F]) is ACEBDF)
    check(extend(tuple[a: A, c: C, e: E], tuple[b: B, d: D, f: F]) is ACEBDF)

  test "Tuples should be joinable":
    check(join(ace as ACE, bdf as BDF) == abcdef)
    check(join(ace as (A, C, E), bdf as BDF) == abcdef)
    check(join(ace as ACE, bdf as (B, D, F)) == abcdef)
    check(join(ace as (A, C, E), bdf as (B, D, F)) == abcdef)

  test "Tuples with labels should be joinable":
    check(join(ace as tuple[a: A, c: C, e: E], bdf as BDF) == abcdef)
    check(join(ace as ACE, bdf as tuple[b: B, d: D, f: F]) == abcdef)
    check(
      join(ace as tuple[a: A, c: C, e: E], bdf as tuple[b: B, d: D, f: F]) == abcdef
    )

  test "Tuples should be derivable from other derived tuples":
    check(WithCD is (A, B, C, D))
    check(WithEF is (A, B, C, D, E, F))
    let joined = join(("foo", 123, 3.14, true) as WithCD, (E(), @[1]) as (E, F))
    check(joined == ("foo", 123, 3.14, true, E(), @[1]))

  test "Join multiple tuple types":
    let joined = join(
      ("foo",) as (A,), (123,) as (B,), (3.14, true) as (C, D), (E(), @[1]) as (E, F)
    )
    check(joined == ("foo", 123, 3.14, true, E(), @[1]))

  test "Join without as":
    let joined = join((X(), E()), (Z(), Y()), ("foo",) as (A,), (123,) as (B,))
    check(joined == (X(), E(), Z(), Y(), "foo", 123))

  test "Extend with generic types":
    var value: Wrapped[(C, D)]
    checkpoint $typeof(value.value)
    check(value.value is (A, B, C, D))
