import unittest, options, necsus/util/fixedSizeTable, sequtils

suite "FixedSizeTable":

    test "Reading and writing values":
        var table = newFixedSizeTable[int32, int32](5)
        table[123] = 456
        check(table[123] == 456)

        table[123] = 789
        check(table[123] == 789)

    test "Maybe reading values":
        var table = newFixedSizeTable[int32, int32](10)
        table[123] = 456
        check(table.maybeGet(123).get() == 456)
        check(table.maybeGet(789).isNone)

    test "Maybe reading pointers":
        var table = newFixedSizeTable[int32, int32](10)
        table[123] = 456
        check(table.maybeGetPointer(123).get()[] == 456)
        check(table.maybeGetPointer(789).isNone)

    test "Contains":
        var table = newFixedSizeTable[int32, int32](10)
        check(123 notin table)
        table[123] = 456
        check(123 in table)

    test "Deleting values":
        var table = newFixedSizeTable[int32, int32](10)
        table[100] = 789
        table.del(100)
        check(100 notin table)
        check(table.maybeGet(100).isNone)

    test "Deleting everything in a table":
        var table = newFixedSizeTable[int, string](5)
        table[1] = "one"
        table[2] = "two"
        table[3] = "three"

        table.del 2
        check(table.pairs.toSeq == @[(1, "one"), (3, "three")])
        check(table[1] == "one")
        check(table[3] == "three")

        table.del 1
        check(table.pairs.toSeq == @[(3, "three")])
        check(table[3] == "three")

        table.del 3
        check(table.pairs.toSeq.len == 0)

    test "Filling a table with values":
        var table = newFixedSizeTable[int, int](100)

        for i in 0..<100:
            table[i] = i + 1000

            for j in max(0, i - 2)..i:
                checkpoint("Checking value of key " & $j)
                require(j in table)
                require(table.maybeGet(j) == some(j + 1000))
                require(table[j] == j + 1000)

        for i in 0..<100:
            require(i in table)
            require(table.maybeGet(i) == some(i + 1000))
            check(table[i] == i + 1000)

    test "Table to string":
        var table = newFixedSizeTable[int32, int32](10)
        check($table == "{}")

        table[1] = 2
        table[3] = 4
        check($table == "{1: 2, 3: 4}")

    test "Table iterators":
        var table = newFixedSizeTable[int, string](10)
        check(table.items.toSeq.len == 0)
        check(table.pairs.toSeq.len == 0)

        table[900] = "a"
        check(table.items.toSeq == @["a"])
        check(table.pairs.toSeq == @[(900, "a")])

        table[950] = "b"
        check(table.items.toSeq == @["a", "b"])
        check(table.pairs.toSeq == @[(900, "a"), (950, "b")])

        table.del(900)
        check(table.items.toSeq == @["b"])
        check(table.pairs.toSeq == @[(950, "b")])

    test "Table setAndRef":
        var table = newFixedSizeTable[int, string](1000)
        var refs = newSeq[ptr string](100)

        for i in 0..<100:
            let strPtr: ptr string = table.setAndRef(i, $i)
            require(strPtr[] == $i)
            refs[i] = strPtr

        for i in 0..<100:
            require(refs[i][] == $i)
            require(table[i] == $i)

    test "Overfilling a table should throw":
        var table = newFixedSizeTable[int, string](4)

        for i in 0..<4:
            table[i] = "foo"

        expect RangeDefect:
            table[5] = "explode"

    test "Reusing slots after deleting them":
        var table = newFixedSizeTable[int, string](4)

        for i in 0..<100:
            table[i] = "foo"
            table.del(i)
