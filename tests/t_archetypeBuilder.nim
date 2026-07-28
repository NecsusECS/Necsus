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
      builder.define(["A"])
      builder.define(["A", "B"])
      builder.define(["A", "B"])
      builder.define(["A", "B", "C"])
      builder.build().toSeq.mapIt($it)

    check(archetypes.toHashSet == ["{A}", "{A, B}", "{A, B, C}"].toHashSet)

  test "Creating archetypes with accessories":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["A"])
      builder.define(["A", "B"])
      builder.define(["A", "B"])
      builder.define(["A", "B", "C"])
      builder.accessory("B")
      builder.build().toSeq.mapIt($it)

    check(archetypes.toHashSet == ["{A, B?}", "{A, B?, C}"].toHashSet)

  test "Allowing for attaching new components to existing archetypes":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["A"])
      builder.define(["A", "B"])

      builder.attachable(["B", "C"], builder.filter([], []))
      builder.attachable(["C", "D"], builder.filter([], []))
      builder.build().toSeq.mapIt($it)

    check(
      archetypes.toHashSet ==
        toHashSet(["{A}", "{A, B, C}", "{A, C, D}", "{A, B, C, D}", "{A, B}"])
    )

  test "Attaching components with accessories":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["A"])
      builder.define(["A", "B"])

      builder.attachable(["B", "C"], builder.filter([], []))
      builder.attachable(["C", "D"], builder.filter([], []))
      builder.accessory("B")
      builder.accessory("C")
      builder.build().toSeq.mapIt($it)

    check(archetypes.toHashSet == toHashSet(["{A, B?, C?}", "{A, B?, C?, D}"]))

  test "Allowing for attaching new components with a matching filter":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["A"])
      builder.define(["A", "B"])
      builder.define(["A", "B", "C"])

      builder.attachable(["D"], builder.filter(["B", "C"], []))
      builder.build().toSeq.mapIt($it)

    check(
      archetypes.toHashSet == toHashSet(["{A}", "{A, B}", "{A, B, C}", "{A, B, C, D}"])
    )

  test "Allowing for attaching new components with an excluding filter":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["A"])
      builder.define(["A", "B"])
      builder.define(["A", "C"])

      builder.attachable(["D"], builder.filter([], ["B", "C"]))
      builder.build().toSeq.mapIt($it)

    check(archetypes.toHashSet == toHashSet(["{A}", "{A, B}", "{A, C}", "{A, D}"]))

  test "Allowing for attaching with a filter that both requires and excludes":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["A"])
      builder.define(["A", "B"])
      builder.define(["A", "B", "C"])

      builder.attachable(["D"], builder.filter(["B"], ["C"]))
      builder.build().toSeq.mapIt($it)

    check(
      archetypes.toHashSet == toHashSet(["{A}", "{A, B}", "{A, B, C}", "{A, B, D}"])
    )

  test "Attaching gated on a component no defined archetype starts with":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["A"])

      builder.attachable(["B"], builder.filter([], []))
      builder.attachable(["C"], builder.filter(["B"], []))
      builder.build().toSeq.mapIt($it)

    check(archetypes.toHashSet == toHashSet(["{A}", "{A, B}", "{A, B, C}"]))

  test "Allowing for detaching new components to existing archetypes":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["A"])
      builder.define(["A", "B"])
      builder.define(["A", "B", "C"])
      builder.define(["A", "B", "C", "D"])

      builder.detachable(["A"])
      builder.detachable(["B", "C"])
      builder.detachable(["C", "D"])
      builder.build().toSeq.mapIt($it)

    check(
      archetypes.toHashSet ==
        toHashSet(
          [
            "{A}", "{A, D}", "{A, B, C}", "{B}", "{D}", "{B, C, D}", "{B, C}",
            "{A, B, C, D}", "{A, B}",
          ]
        )
    )

  test "Detaching components with accessories":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["A"])
      builder.define(["A", "B"])
      builder.define(["A", "B", "C"])
      builder.define(["A", "B", "C", "D"])

      builder.detachable(["A"])
      builder.detachable(["B", "C"])
      builder.detachable(["C", "D"])

      builder.accessory("B")
      builder.accessory("C")
      builder.build().toSeq.mapIt($it)

    check(
      archetypes.toHashSet ==
        toHashSet(["{A, B?, C?}", "{B?, C?}", "{A, B?, C?, D}", "{B?, C?, D}"])
    )

  test "Attaching and detaching in a single action":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["A", "B"])
      builder.define(["A", "B", "C"])
      builder.define(["B", "C"])

      builder.attachDetach(["D", "E"], ["A"])
      builder.build().toSeq.mapIt($it)

    check(
      archetypes.toHashSet ==
        toHashSet(["{A, B}", "{A, B, C}", "{B, C}", "{B, D, E}", "{B, C, D, E}"])
    )

  test "Detaching should require presence of all bits":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["A", "B", "C"])
      builder.define(["B", "C", "D"])

      builder.detachable(["C", "D"])
      builder.build().toSeq.mapIt($it)

    check(archetypes.toHashSet == toHashSet(["{A, B, C}", "{B, C, D}", "{B}"]))

  test "Optional detaching":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["A", "B", "C", "D"])
      builder.define(["A", "C", "D", "E"])

      builder.detachable(["C", "D"], ["E"])
      builder.build().toSeq.mapIt($it)

    check(
      archetypes.toHashSet ==
        toHashSet(["{A, B, C, D}", "{A, C, D, E}", "{A, B}", "{A}"])
    )

  test "Require that the same archetype be added with elements in the same order":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["A", "B", "C"])
      builder.define(["A", "B", "C"])
      builder.define(["C", "A", "B"])
      builder.build().toSeq.mapIt($it)

    check(archetypes.toHashSet == ["{A, B, C}"].toHashSet)

  test "Component iteration":
    const components = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["A", "B"])
      builder.define(["B", "C"])
      builder.attachDetach(["D", "E"], ["A"])
      builder.attachable(["F"], builder.filter(["C"], []))
      builder.allComponents.toSeq

    check(components.toHashSet == ["A", "B", "C", "D", "E", "F"].toHashSet)

suite "Accessories and the shape of the graph walk":
  ## An accessory never changes which archetype an entity belongs to, so the walk is free
  ## to stop treating one as a dimension of the search -- but only when nothing in the
  ## graph can tell the two branches apart. These pin down where that line falls.

  test "An accessory only reaches the archetypes it can be attached to":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["acc1A"])
      builder.define(["acc1B"])
      builder.accessory("acc1D")
      builder.attachable(["acc1D"], builder.filter(["acc1A"], []))
      builder.build().toSeq.mapIt($it)

    # The branch the filter never reaches must not pick the accessory up
    check(archetypes.toHashSet == toHashSet(["{acc1A, acc1D?}", "{acc1B}"]))

  test "An accessory can gate another accessory":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["acc2A"])
      builder.define(["acc2B"])
      builder.accessory("acc2D")
      builder.accessory("acc2E")
      builder.attachable(["acc2D"], builder.filter(["acc2A"], []))
      builder.attachable(["acc2E"], builder.filter(["acc2D"], []))
      builder.build().toSeq.mapIt($it)

    check(archetypes.toHashSet == toHashSet(["{acc2A, acc2D?, acc2E?}", "{acc2B}"]))

  test "A filter that excludes an accessory is not fooled by it being optional":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["acc3A", "acc3D"])
      builder.accessory("acc3D")
      builder.attachable(["acc3E"], builder.filter([], ["acc3D"]))
      builder.build().toSeq.mapIt($it)

    # Every entity here carries the accessory, so the exclusion can never let anything by
    check(archetypes.toHashSet == toHashSet(["{acc3A, acc3D?}"]))

  test "An accessory a detach requires still splits the graph":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["acc4A", "acc4B"])
      builder.define(["acc4A", "acc4B", "acc4D"])
      builder.accessory("acc4D")
      builder.detachable(["acc4B", "acc4D"])
      builder.build().toSeq.mapIt($it)

    # The detach only applies where the accessory is present, so the branch without it
    # has to stay reachable in its own right for `{acc4A}` to ever be found
    check(archetypes.toHashSet == toHashSet(["{acc4A, acc4B, acc4D?}", "{acc4A}"]))

  test "Detaching an accessory on its own":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["acc5A", "acc5D"])
      builder.accessory("acc5D")
      builder.detachable(["acc5D"])
      builder.build().toSeq.mapIt($it)

    check(archetypes.toHashSet == toHashSet(["{acc5A, acc5D?}"]))

  test "An accessory that can be both attached and detached settles":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["acc6A"])
      builder.accessory("acc6D")
      builder.attachable(["acc6D"], builder.filter([], []))
      builder.detachable(["acc6D"])
      builder.build().toSeq.mapIt($it)

    check(archetypes.toHashSet == toHashSet(["{acc6A, acc6D?}"]))

  test "Independent accessories do not multiply the archetypes they land on":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["acc7A"])
      builder.define(["acc7B"])
      builder.accessory("acc7D")
      builder.accessory("acc7E")
      builder.accessory("acc7F")
      builder.attachable(["acc7D"], builder.filter(["acc7A"], []))
      builder.attachable(["acc7E"], builder.filter(["acc7A"], []))
      builder.attachable(["acc7F"], builder.filter(["acc7A"], []))
      builder.build().toSeq.mapIt($it)

    check(
      archetypes.toHashSet ==
        toHashSet(["{acc7A, acc7D?, acc7E?, acc7F?}", "{acc7B}"])
    )

  test "An accessory detached alongside a component it does not travel with":
    const archetypes = block:
      var builder = newArchetypeBuilder[string]()
      builder.define(["acc8A", "acc8B", "acc8D"])
      builder.define(["acc8A", "acc8C"])
      builder.accessory("acc8D")
      # `acc8D` rides along with the detach, but only `acc8B` decides whether it applies
      builder.detachable(["acc8B"], ["acc8D"])
      builder.build().toSeq.mapIt($it)

    check(
      archetypes.toHashSet ==
        toHashSet(["{acc8A, acc8B, acc8D?}", "{acc8A, acc8C}", "{acc8A}"])
    )
