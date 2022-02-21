import unittest, necsus/util/openAddrEntry

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

suite "OpenAddrTable entries":

    test "Encoding values":
        assertEncoding[int32, int32](0x7FFFFFFF, 0x7FFFFFFF)
        assertEncoding[int32, int32](0, 0)
        assertEncoding[int32, int32](123, 456)
        assertEncoding[int16, int16](123, 456)
