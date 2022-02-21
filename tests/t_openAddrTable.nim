import unittest, options, necsus/util/openAddrTable

suite "OpenAddrTable":

    test "Reading and writing values":
        var table = newOpenAddrTable[int32, int32](10)
        table[123] = 456
        check(table[123] == 456)

        table[123] = 789
        check(table[123] == 789)

    test "Reading values that don't exist":
        var table = newOpenAddrTable[int32, int32](10)
        table[123] = 456
        check(table.maybeGet(123).get() == 456)
        check(table.maybeGet(789).isNone)

    test "Maybe reading values":
        var table = newOpenAddrTable[int32, int32](10)
        expect KeyError:
            discard table[123]

    test "Deleting values":
        var table = newOpenAddrTable[int32, int32](10)
        table[100] = 789
        table.del(100)
        expect KeyError:
            discard table[100]

    test "Deleting from a filled table":
        var table = newOpenAddrTable[int32, int32](2)
        for i in 1.int32..4:
            table[i] = i
        table.del(100)
        for i in 1.int32..4:
            check(table[i] == i)

    test "Contains":
        var table = newOpenAddrTable[int32, int32](10)
        check(123 notin table)
        table[123] = 456
        check(123 in table)
        table.del 123
        check(123 notin table)

    test "Filling a table with values":
        var table = newOpenAddrTable[int32, int32](100)
        for i in 0..<100:
            table[i.int32] = i.int32
            check(table[i.int32] == i.int32)
        for i in 0..<100:
            check(table[i.int32] == i.int32)

    test "Setting new values":
        var table = newOpenAddrTable[int8, int8](100)

        for i in 0'i8..<10:
            table.setNew(i, i)
            check(table[i] == i)

        for i in 0'i8..<10:
            expect KeyError:
                table.setNew(i, i * 2)

        for i in 0'i8..<10:
            check(table[i] == i)

    test "Table to string":
        var table = newOpenAddrTable[int32, int32](10)
        check($table == "{}")

        table[1] = 2
        table[3] = 4
        check($table == "{1: 2, 3: 4}")
