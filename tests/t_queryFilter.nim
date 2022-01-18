import unittest, necsus/runtime/queryFilter

type TestEnum = enum A, B, C, D

suite "QueryFilter":

    test "Match all values":
        let filter = filterAll[TestEnum]()
        check(filter.evaluate({A, B}))
        check(filter.evaluate({B, C}))
        check(filter.evaluate({C, D}))

    test "Match values containing the given components":
        let filterAB = filterMatching[TestEnum]({A, B})
        check(filterAB.evaluate({A, B}))
        check(not filterAB.evaluate({B, C}))
        check(not filterAB.evaluate({C, D}))

        let filterBCD = filterMatching[TestEnum]({B, C, D})
        check(not filterBCD.evaluate({A, B}))
        check(not filterBCD.evaluate({B, C}))
        check(not filterBCD.evaluate({C, D}))
        check(filterBCD.evaluate({B, C, D}))
