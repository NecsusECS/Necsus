import unittest, threadpool, necsus/util/openAddrTable

template testParallelInsets(tableSize: int, values: int) =
    var table = newOpenAddrTable[int, int](tableSize)

    proc assignAndCheck(keyval: int) =
        table[keyval] = keyval
        if keyval notin table:
            echo table.dump
            assert(false, "Key does not exist " & $keyval)

    for i in 0..<values:
        spawn assignAndCheck(i)

    sync()

    for i in 0..<values:
        check(table[i] == i)

suite "OpenAddrTable parallel sets":

    for i in 0..10:
        test "Parallel setting of values #" & $i:
            testParallelInsets(tableSize = 10_000, values = 1_000)

    for i in 0..10:
        test "Resizing a table #" & $i:
            testParallelInsets(tableSize = 4, values = 130)
