import unittest, sequtils, hashes, algorithm, necsus/util/openAddr

type Collider = object
  ## A key whose hash deliberately collides, to force the probe to walk
  value: int

proc hash(key: Collider): Hash =
  Hash(key.value mod 4)

suite "OpenTable":
  test "Reading back what was written":
    var table = initOpenTable[string, int]()
    table["a"] = 1
    table["b"] = 2
    table["a"] = 3

    check(table.len == 2)
    check(table["a"] == 3)
    check(table["b"] == 2)
    check("a" in table)
    check("c" notin table)
    check(table.getOrDefault("c") == 0)

  test "A table that was never initialized":
    var table: OpenTable[string, int]
    check(table.len == 0)
    check("a" notin table)
    check(table.getOrDefault("a") == 0)

    table["a"] = 1
    check(table["a"] == 1)

  test "Missing keys":
    var table = initOpenTable[string, int]()
    expect KeyError:
      discard table["nope"]

  test "Slots":
    var table = initOpenTable[string, int]()
    let slot = table.slotFor("a")
    check(table.value(slot) == 0)
    check(table.key(slot) == "a")
    table.setValue(slot, 7)

    check(table.slotFor("a") == slot)
    check(table["a"] == 7)

  test "Iteration follows insertion order":
    var table = initOpenTable[string, int]()
    for i, key in ["d", "c", "b", "a"]:
      table[key] = i

    check(table.pairs.toSeq == @[("d", 0), ("c", 1), ("b", 2), ("a", 3)])
    check(table.keys.toSeq == @["d", "c", "b", "a"])
    check(table.values.toSeq == @[0, 1, 2, 3])

  test "Growing past the initial bucket count":
    var table = initOpenTable[int, int]()
    for i in 0 ..< 1000:
      table[i] = i * 2

    check(table.len == 1000)
    for i in 0 ..< 1000:
      check(table[i] == i * 2)
    check(1000 notin table)

  test "Keys that hash to the same bucket":
    var table = initOpenTable[Collider, int]()
    for i in 0 ..< 50:
      table[Collider(value: i)] = i

    check(table.len == 50)
    for i in 0 ..< 50:
      check(table[Collider(value: i)] == i)

  test "Sizing up front":
    var table = initOpenTable[int, int](500)
    for i in 0 ..< 500:
      table[i] = i
    check(table.len == 500)

  test "Usable from the VM":
    const total = block:
      var table = initOpenTable[string, int]()
      for i in 0 ..< 100:
        table["key" & $i] = i
      var accum = 0
      for _, value in table:
        accum += value
      accum

    check(total == 4950)

suite "OpenSet":
  test "Adding and testing membership":
    var values = initOpenSet[string]()
    values.incl("a")
    values.incl("b")
    values.incl("a")

    check(values.len == 2)
    check(values.card == 2)
    check("a" in values)
    check("c" notin values)

  test "A set that was never initialized":
    var values: OpenSet[string]
    check(values.len == 0)
    check("a" notin values)

    values.incl("a")
    check("a" in values)

  test "containsOrIncl reports what was already there":
    var values = initOpenSet[string]()
    check(not values.containsOrIncl("a"))
    check(values.containsOrIncl("a"))
    check(values.len == 1)

  test "Iteration follows insertion order":
    var values = initOpenSet[string]()
    for key in ["d", "c", "b", "a"]:
      values.incl(key)
    check(values.toSeq == @["d", "c", "b", "a"])

  test "Growing past the initial bucket count":
    var values = initOpenSet[int]()
    for i in 0 ..< 1000:
      values.incl(i)

    check(values.len == 1000)
    for i in 0 ..< 1000:
      check(i in values)
    check(1000 notin values)

  test "Keys that hash to the same bucket":
    var values = initOpenSet[Collider]()
    for i in 0 ..< 50:
      values.incl(Collider(value: i))

    check(values.len == 50)
    for i in 0 ..< 50:
      check(Collider(value: i) in values)
    check(Collider(value: 50) notin values)

  test "Usable from the VM":
    const unique = block:
      var values = initOpenSet[int]()
      for i in 0 ..< 100:
        values.incl(i mod 30)
      values.toSeq.sorted()

    check(unique == (0 ..< 30).toSeq)
