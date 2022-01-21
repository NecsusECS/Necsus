import unittest, necsus/runtime/packedIntTable, sequtils

suite "PackedIntTable":

    var table = newPackedIntTable[string](5)
    table[1] = "one"
    table[2] = "two"
    table[3] = "three"

    test "Debug string":
        check($table == "{1: one, 2: two, 3: three}")

    test "Setting and reading values":
        check(table[1] == "one")
        check(table[2] == "two")
        check(table[3] == "three")
        expect(KeyError):
            discard table[4]
        expect(KeyError):
            discard table[0]

    test "Value iteration":
        check(table.toSeq == @["one", "two", "three"])

    test "Pair iteration":
        check(table.pairs.toSeq == @[(1, "one"), (2, "two"), (3, "three")])

    test "Contains":
        check(1 in table)
        check(5 notin table)

    test "Sparse keys":
        var sparseTable = newPackedIntTable[string](100)
        sparseTable[0] = "zero"
        sparseTable[10] = "ten"
        sparseTable[20] = "twenty"
        sparseTable[30] = "thirty"
        check(sparseTable.toSeq == @["zero", "ten", "twenty", "thirty"])

    test "Deleting keys":
        var deletable = newPackedIntTable[string](5)
        deletable[1] = "one"
        deletable[2] = "two"
        deletable[3] = "three"

        expect(KeyError):
            deletable.del 4

        deletable.del 2
        check(deletable.pairs.toSeq == @[(1, "one"), (3, "three")])
        check(deletable[1] == "one")
        check(deletable[3] == "three")

        deletable.del 1
        check(deletable.pairs.toSeq == @[(3, "three")])
        check(deletable[3] == "three")

        deletable.del 3
        check(deletable.pairs.toSeq.len == 0)

        expect(KeyError):
            deletable.del 3

    test "Filling the table beyond capacity":
        var fill = newPackedIntTable[int](5)
        for i in 0..1000:
            fill[i] = i
        check(fill.toSeq == (0..1000).toSeq)

    test "Take address of a key":
        let ref1 = table.reference(1)
        let ref2 = table.reference(2)
        let ref3 = table.reference(3)

        check(table[ref1] == "one")
        check(table[ref2] == "two")
        check(table[ref3] == "three")

        table.del(1)
        expect(KeyError):
            discard table[ref1]
        check(table[ref2] == "two")
        check(table[ref3] == "three")

        table.del(3)
        expect(KeyError):
            discard table[ref1]
        expect(KeyError):
            discard table[ref3]
        check(table[ref2] == "two")

        table.del(2)
        expect(KeyError):
            discard table[ref1]
        expect(KeyError):
            discard table[ref3]
        expect(KeyError):
            discard table[ref2]

    test "Set key and take reference":
        var refTable = newPackedIntTable[string](5)
        check(refTable[refTable.setAndRef(50, "foo")] == "foo")
        check(refTable[refTable.setAndRef(1000, "bar")] == "bar")
        check(refTable[refTable.setAndRef(10000, "baz")] == "baz")
        check(refTable.toSeq == @["foo", "bar", "baz"])