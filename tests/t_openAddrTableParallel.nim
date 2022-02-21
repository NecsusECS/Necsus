import unittest, threadpool, necsus/util/openAddrTable

template testParallelInsets(tableSize: int, values: int) =
    var table = newOpenAddrTable[int32, int32](tableSize)

    proc assignAndCheck(keyval: int) =
        table[keyval.int32] = keyval.int32
        check(table[keyval.int32] == keyval.int32)

    for i in 0..<values:
        spawn assignAndCheck(i)

    sync()

    for i in 0..<values:
        check(table[i.int32] == i.int32)

suite "OpenAddrTable parallel sets":

    for i in 0..10:
        test "Parallel setting of values #" & $i:
            testParallelInsets(tableSize = 10_000, values = 1_000)

    for i in 0..10:
        test "Resizing a table #" & $i:
            testParallelInsets(tableSize = 4, values = 130)
