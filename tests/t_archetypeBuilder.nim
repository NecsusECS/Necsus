import unittest, necsus/compiletime/archetypeBuilder, sequtils, sets, tables

var ids: uint16 = 0
var lookup = initTable[string, uint16]()
proc uniqueId(value: string): uint16 =
    if not lookup.hasKey(value):
        lookup[value] = ids
        ids += 1
    return lookup[value]

suite "Creating archetypes":
    test "Creating archetypes of values":

        var builder = newArchetypeBuilder[string]()
        builder.define([ "A" ])
        builder.define([ "A", "B" ])
        builder.define([ "A", "B" ])
        builder.define([ "A", "B", "C" ])
        let archetypes = builder.build()

        check(archetypes.toSeq.mapIt($it).toHashSet == [ "{A}", "{A, B}", "{A, B, C}" ].toHashSet)

    test "Allowing for attaching new components to existing archetypes":
        var builder = newArchetypeBuilder[string]()
        builder.define([ "A" ])
        builder.define([ "A", "B" ])

        builder.attachable([ "B", "C" ], builder.filter([], []))
        builder.attachable([ "C", "D" ], builder.filter([], []))
        let archetypes = builder.build()

        check(archetypes.toSeq.mapIt($it).toHashSet == toHashSet([
            "{A}", "{A, B, C}", "{A, C, D}", "{A, B, C, D}", "{A, B}"
        ]))

    test "Allowing for attaching new components with a matching filter":
        var builder = newArchetypeBuilder[string]()
        builder.define([ "A" ])
        builder.define([ "A", "B" ])
        builder.define([ "A", "B", "C"])

        builder.attachable([ "D" ], builder.filter([ "B", "C" ], []))
        let archetypes = builder.build()

        check(archetypes.toSeq.mapIt($it).toHashSet == toHashSet([
            "{A}", "{A, B}", "{A, B, C}", "{A, B, C, D}"
        ]))

    test "Allowing for attaching new components with an excluding filter":
        var builder = newArchetypeBuilder[string]()
        builder.define([ "A" ])
        builder.define([ "A", "B" ])
        builder.define([ "A", "C"])

        builder.attachable([ "D" ], builder.filter([], [ "B", "C" ]))
        let archetypes = builder.build()

        check(archetypes.toSeq.mapIt($it).toHashSet == toHashSet([
            "{A}", "{A, B}", "{A, C}", "{A, D}"
        ]))

    test "Allowing for detaching new components to existing archetypes":
        var builder = newArchetypeBuilder[string]()
        builder.define([ "A" ])
        builder.define([ "A", "B" ])
        builder.define([ "A", "B", "C" ])
        builder.define([ "A", "B", "C", "D" ])

        builder.detachable([ "A" ])
        builder.detachable([ "B", "C" ])
        builder.detachable([ "C", "D" ])
        let archetypes = builder.build()

        check(archetypes.toSeq.mapIt($it).toHashSet == toHashSet([
            "{A}", "{A, D}", "{A, B, C}", "{B}", "{D}", "{B, C, D}", "{B, C}", "{A, B, C, D}", "{A, B}"
        ]))

    test "Attaching and detaching in a single action":
        var builder = newArchetypeBuilder[string]()
        builder.define([ "A", "B" ])
        builder.define([ "A", "B", "C" ])
        builder.define([ "B", "C" ])

        builder.attachDetach([ "D", "E" ], [ "A" ])
        let archetypes = builder.build()

        check(archetypes.toSeq.mapIt($it).toHashSet == toHashSet([
            "{A, B}", "{A, B, C}", "{B, C}", "{B, D, E}", "{B, C, D, E}"
        ]))

    test "Require that the same archetype be added with elements in the same order":
        var builder = newArchetypeBuilder[string]()
        builder.define([ "A", "B", "C" ])
        builder.define([ "A", "B", "C" ])
        builder.define([ "C", "A", "B" ])

        check(builder.build().toSeq.mapIt($it).toHashSet == [ "{A, B, C}" ].toHashSet)
