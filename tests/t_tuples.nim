import unittest, necsus/runtime/tuples

type
    A = string
    B = int
    C = float
    D = bool
    E = object
    F = seq[int]

    ACE = (A, C, E)
    BDF = (B, D, F)
    ABCDEF = (A, B, C, D, E, F)

let ace: ACE = ("foo", 3.14, E())
let bdf: BDF = (123, true, @[1])
let abcdef: ABCDEF = ("foo", 123, 3.14, true, E(), @[1])

suite "Tuple tools":
    test "Tuples should be extendable":
        check(extend(ACE, BDF) is ABCDEF)
        check(extend((A, C, E), BDF) is ABCDEF)
        check(extend(ACE, (B, D, F)) is ABCDEF)
        check(extend((A, C, E), (B, D, F)) is ABCDEF)

    test "Tuples with labels hsould be extendable":
        check(extend(tuple[a: A, c: C, e: E], BDF) is ABCDEF)
        check(extend(ACE, tuple[b: B, d: D, f: F]) is ABCDEF)
        check(extend(tuple[a: A, c: C, e: E], tuple[b: B, d: D, f: F]) is ABCDEF)

    test "Tuples should be joinable":

        check(join(ACE, BDF, ace, bdf) == abcdef)
        check(join((A, C, E), BDF, ace, bdf) == abcdef)
        check(join(ACE, (B, D, F), ace, bdf) == abcdef)
        check(join((A, C, E), (B, D, F), ace, bdf) == abcdef)

    test "Tuples with labels should be joinable":
        check(join(tuple[a: A, c: C, e: E], BDF, ace, bdf) == abcdef)
        check(join(ACE, tuple[b: B, d: D, f: F], ace, bdf) == abcdef)
        check(join(tuple[a: A, c: C, e: E], tuple[b: B, d: D, f: F], ace, bdf) == abcdef)