import unittest, necsus/compiletime/grouper, sequtils

suite "Value grouping":
    test "Creating a group of values":
        var builder = newGrouper[string]()
        builder.add([ "A", "B", "C", "D", "E", "F", "G" ])
        builder.add([ "E", "F", "G", "H", "I", "J" ])
        let groups = builder.build()

        check(groups.toSeq.mapIt($it) == [ "{A, B, C, D}", "{E, F, G}", "{H, I, J}" ])

    test "Looking up the group of a value":

        var builder = newGrouper[string]()
        builder.add([ "A", "B", "C", "D" ])
        builder.add([ "C", "D", "E", "F", "G" ])
        builder.add([ "G", "H", "I" ])
        builder.add([ "J", "K", "L", "M", "N" ])
        let groups = builder.build()

        check($groups["A"] == "{A, B}")
        check($groups["B"] == "{A, B}")
        check($groups["C"] == "{C, D}")
        check($groups["D"] == "{C, D}")
        check($groups["E"] == "{E, F}")
        check($groups["F"] == "{E, F}")
        check($groups["G"] == "{G}")
        check($groups["H"] == "{H, I}")
        check($groups["I"] == "{H, I}")
        check($groups["J"] == "{J, K, L, M, N}")
        check($groups["K"] == "{J, K, L, M, N}")
        check($groups["L"] == "{J, K, L, M, N}")
        check($groups["M"] == "{J, K, L, M, N}")
        check($groups["N"] == "{J, K, L, M, N}")

    test "Looking up indexes for values in a group":
        var builder = newGrouper[string]()
        builder.add([ "A", "B", "C", "D", "E", "F" ])
        builder.add([ "D", "E", "F", "G", "H", "I" ])
        let groups = builder.build()

        check(groups["A"]["A"] == 0)
        check(groups["A"]["B"] == 1)
        check(groups["A"]["C"] == 2)
        check(groups["D"]["D"] == 0)
        check(groups["D"]["E"] == 1)
        check(groups["D"]["F"] == 2)
        check(groups["G"]["G"] == 0)
        check(groups["G"]["H"] == 1)
        check(groups["G"]["I"] == 2)

    test "Group equality":
        var builder = newGrouper[string]()
        builder.add([ "A", "B", "C" ])
        builder.add([ "D", "E", "F" ])
        let groups = builder.build()

        check(groups["A"] == groups["B"])
        check(groups["E"] == groups["F"])
