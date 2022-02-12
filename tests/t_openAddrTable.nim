import unittest, threadpool, intsets, random, sequtils, algorithm, options
include necsus/runtime/openAddrTable

proc assertEncoding[K, V](key: K, value: V, state: static EntryState) =
    let entry = encode[K, V](key, value, state)
    check(entry.key == key)
    check(entry.value == value)
    check($entry == ($key & ": " & $value))
    check(entry.isState(state))
    case state
    of UsedKey:
        check(not entry.isState(UnusedKey))
        check(not entry.isState(TombstonedKey))
        check(not entry.isWritable)
    of UnusedKey:
        check(not entry.isState(UsedKey))
        check(not entry.isState(TombstonedKey))
        check(entry.isWritable)
    of TombstonedKey:
        check(not entry.isState(UsedKey))
        check(not entry.isState(UnusedKey))
        check(entry.isWritable)

proc assertEncoding[K, V](key: K, value: V) =
    assertEncoding(key, value, UnusedKey)
    assertEncoding(key, value, UsedKey)
    assertEncoding(key, value, TombstonedKey)

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


suite "OpenAddrTable":

    test "Encoding values":
        assertEncoding[int32, int32](0x7FFFFFFF, 0x7FFFFFFF)
        assertEncoding[int32, int32](0, 0)
        assertEncoding[int32, int32](123, 456)
        assertEncoding[int16, int16](123, 456)

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

    for i in 0..10:
        test "Parallel setting of values #" & $i:
            testParallelInsets(tableSize = 10_000, values = 1_000)

    for i in 0..10:
        test "Resizing a table #" & $i:
            testParallelInsets(tableSize = 4, values = 130)

    type
        ActionKind = enum SetKey, ChangeKey, DeleteKey

        Action = object
            key: int16
            case kind: ActionKind
            of SetKey, ChangeKey:
                value: int16
            of DeleteKey:
                discard

    proc `$`(action: Action): string =
        case action.kind
        of SetKey: "SET " & $action.key & " = " & $action.value
        of ChangeKey: "UPD " & $action.key & " = " & $action.value
        of DeleteKey: "DEL " & $action.key

    proc randInt16(random: var Rand): int16 =
        (random.next() mod int16.high.uint64).int16

    proc randomAction(random: var Rand, existingKeys: IntSet): Action =
        if existingKeys.len == 0:
            return Action(kind: SetKey, key: random.randInt16(), value: random.randInt16())

        case (random.next() mod 4).int32:
        of 0: return Action(kind: DeleteKey, key: random.sample(existingKeys.toSeq()).int16)
        of 1: return Action(kind: ChangeKey, key: random.sample(existingKeys.toSeq()).int16, value: random.randInt16())
        else: return Action(kind: SetKey, key: random.randInt16(), value: random.randInt16())

    for i in 0..50:
        test "Bulk action tests #" & $i:
            var table = newOpenAddrTable[int16, int16](10)
            var setKeys = initIntSet()
            var actions = newSeq[Action]()
            var random = initRand(i)

            for i in 0..100:
                let action = random.randomAction(setKeys)
                actions.add(action)
                checkpoint $action
                case action.kind
                of SetKey, ChangeKey:
                    table[action.key] = action.value
                    check(table[action.key] == action.value)
                    setKeys.incl action.key
                of DeleteKey:
                    table.del(action.key)
                    expect KeyError: discard table[action.key]
                    setKeys.excl action.key
                checkpoint table.dump()

            var checkedKeys = initIntSet()
            for action in actions.reversed():
                if action.key notin checkedKeys:
                    checkpoint "Checking " & $action
                    checkedKeys.incl action.key
                    case action.kind
                    of SetKey, ChangeKey: check(table[action.key] == action.value)
                    of DeleteKey: expect KeyError: discard table[action.key]
