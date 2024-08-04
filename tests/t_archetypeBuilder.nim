import unittest, necsus/compiletime/archetypeBuilder, sequtils, sets, tables

var ids {.compileTime.}: uint16 = 0
var lookup {.compileTime.} = initTable[string, uint16]()
proc uniqueId(value: string): uint16 =
    if not lookup.hasKey(value):
        lookup[value] = ids
        ids += 1
    return lookup[value]

suite "Creating archetypes":
    test "Creating archetypes of values":

        const archetypes = block:
            var builder = newArchetypeBuilder[string]()
            builder.define([ "A" ])
            builder.define([ "A", "B" ])
            builder.define([ "A", "B" ])
            builder.define([ "A", "B", "C" ])
            builder.build().toSeq.mapIt($it)

        check(archetypes.toHashSet == [ "{A}", "{A, B}", "{A, B, C}" ].toHashSet)

    test "Creating archetypes with accessories":

        const archetypes = block:
            var builder = newArchetypeBuilder[string]()
            builder.define([ "A" ])
            builder.define([ "A", "B" ])
            builder.define([ "A", "B" ])
            builder.define([ "A", "B", "C" ])
            builder.accessory("B")
            builder.build().toSeq.mapIt($it)

        check(archetypes.toHashSet == [ "{A, B?}", "{A, B?, C}" ].toHashSet)

    test "Allowing for attaching new components to existing archetypes":
        const archetypes = block:
            var builder = newArchetypeBuilder[string]()
            builder.define([ "A" ])
            builder.define([ "A", "B" ])

            builder.attachable([ "B", "C" ], builder.filter([], []))
            builder.attachable([ "C", "D" ], builder.filter([], []))
            builder.build().toSeq.mapIt($it)

        check(archetypes.toHashSet == toHashSet([
            "{A}", "{A, B, C}", "{A, C, D}", "{A, B, C, D}", "{A, B}"
        ]))

    test "Attaching components with accessories":
        const archetypes = block:
            var builder = newArchetypeBuilder[string]()
            builder.define([ "A" ])
            builder.define([ "A", "B" ])

            builder.attachable([ "B", "C" ], builder.filter([], []))
            builder.attachable([ "C", "D" ], builder.filter([], []))
            builder.accessory("B")
            builder.accessory("C")
            builder.build().toSeq.mapIt($it)

        check(archetypes.toHashSet == toHashSet([ "{A, B?, C?}", "{A, B?, C?, D}" ]))

    test "Allowing for attaching new components with a matching filter":
        const archetypes = block:
            var builder = newArchetypeBuilder[string]()
            builder.define([ "A" ])
            builder.define([ "A", "B" ])
            builder.define([ "A", "B", "C"])

            builder.attachable([ "D" ], builder.filter([ "B", "C" ], []))
            builder.build().toSeq.mapIt($it)

        check(archetypes.toHashSet == toHashSet([ "{A}", "{A, B}", "{A, B, C}", "{A, B, C, D}" ]))

    test "Allowing for attaching new components with an excluding filter":
        const archetypes = block:
            var builder = newArchetypeBuilder[string]()
            builder.define([ "A" ])
            builder.define([ "A", "B" ])
            builder.define([ "A", "C"])

            builder.attachable([ "D" ], builder.filter([], [ "B", "C" ]))
            builder.build().toSeq.mapIt($it)

        check(archetypes.toHashSet == toHashSet([ "{A}", "{A, B}", "{A, C}", "{A, D}" ]))

    test "Allowing for detaching new components to existing archetypes":
        const archetypes = block:
            var builder = newArchetypeBuilder[string]()
            builder.define([ "A" ])
            builder.define([ "A", "B" ])
            builder.define([ "A", "B", "C" ])
            builder.define([ "A", "B", "C", "D" ])

            builder.detachable([ "A" ])
            builder.detachable([ "B", "C" ])
            builder.detachable([ "C", "D" ])
            builder.build().toSeq.mapIt($it)

        check(archetypes.toHashSet == toHashSet([
            "{A}", "{A, D}", "{A, B, C}", "{B}", "{D}", "{B, C, D}", "{B, C}", "{A, B, C, D}", "{A, B}"
        ]))

    test "Detaching components with accessories":
        const archetypes = block:
            var builder = newArchetypeBuilder[string]()
            builder.define([ "A" ])
            builder.define([ "A", "B" ])
            builder.define([ "A", "B", "C" ])
            builder.define([ "A", "B", "C", "D" ])

            builder.detachable([ "A" ])
            builder.detachable([ "B", "C" ])
            builder.detachable([ "C", "D" ])

            builder.accessory("B")
            builder.accessory("C")
            builder.build().toSeq.mapIt($it)

        check(archetypes.toHashSet == toHashSet([
            "{A, B?, C?}", "{B?, C?}", "{A, B?, C?, D}", "{B?, C?, D}"
        ]))

    test "Attaching and detaching in a single action":
        const archetypes = block:
            var builder = newArchetypeBuilder[string]()
            builder.define([ "A", "B" ])
            builder.define([ "A", "B", "C" ])
            builder.define([ "B", "C" ])

            builder.attachDetach([ "D", "E" ], [ "A" ])
            builder.build().toSeq.mapIt($it)

        check(archetypes.toHashSet == toHashSet([
            "{A, B}", "{A, B, C}", "{B, C}", "{B, D, E}", "{B, C, D, E}"
        ]))

    test "Detaching should require presence of all bits":
        const archetypes = block:
            var builder = newArchetypeBuilder[string]()
            builder.define([ "A", "B", "C" ])
            builder.define([ "B", "C", "D" ])

            builder.detachable([ "C", "D" ])
            builder.build().toSeq.mapIt($it)

        check(archetypes.toHashSet == toHashSet([ "{A, B, C}", "{B, C, D}", "{B}" ]))

    test "Optional detaching":
        const archetypes = block:
            var builder = newArchetypeBuilder[string]()
            builder.define([ "A", "B", "C", "D" ])
            builder.define([ "A", "C", "D", "E" ])

            builder.detachable([ "C", "D" ], [ "E" ])
            builder.build().toSeq.mapIt($it)

        check(archetypes.toHashSet == toHashSet([ "{A, B, C, D}", "{A, C, D, E}", "{A, B}", "{A}" ]))

    test "Require that the same archetype be added with elements in the same order":
        const archetypes = block:
            var builder = newArchetypeBuilder[string]()
            builder.define([ "A", "B", "C" ])
            builder.define([ "A", "B", "C" ])
            builder.define([ "C", "A", "B" ])
            builder.build().toSeq.mapIt($it)

        check(archetypes.toHashSet == [ "{A, B, C}" ].toHashSet)
