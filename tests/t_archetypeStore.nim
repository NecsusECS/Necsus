import unittest, sequtils
import necsus/runtime/[archetypeStore, entityId, world]

type
  Position = object
    x, y: int32

  Label = object
    value: string

  Flag = object
    on: uint8

  Wide = object
    value: int64

  Tracked = object
    value: int

var destroyed: seq[int]

proc `=destroy`(tracked: var Tracked) =
  ## Records every value that gets destroyed. A zeroed slot was never a value anybody
  ## stored, so it is not worth counting
  if tracked.value != 0:
    destroyed.add(tracked.value)

const
  cPosition = ComponentId(0)
  cLabel = ComponentId(1)
  cFlag = ComponentId(2)
  cWide = ComponentId(3)
  cTracked = ComponentId(4)
  cAbsent = ComponentId(5)
  COMPONENT_COUNT = 6

const
  colPosition = columnDef[Position](cPosition)
  colLabel = columnDef[Label](cLabel)
  colFlag = columnDef[Flag](cFlag)
  colWide = columnDef[Wide](cWide)
  colTracked = columnDef[Tracked](cTracked)

template newStore(capacity: Natural, columns: untyped): untyped =
  ## Every store in here is sized for the same set of components, since the component
  ## count is a property of the app rather than of any one archetype
  newArchetypeStore[COMPONENT_COUNT](ArchetypeId(1), capacity, columns)

suite "ColumnStore":
  test "An archetype with no room for anything":
    var store = newStore(0, [colPosition, colLabel])
    check(store.len == 0)
    check(store.rows == 0)
    check(store.column(cPosition).isEmpty)
    check(store.column(cLabel).isEmpty)
    check(store.entityIds.toSeq.len == 0)

  test "Storing components and reading them back":
    var store = newStore(8, [colPosition, colLabel])

    let idx = store.reserve(EntityId(7))
    check(idx == 0)
    check(store.len == 1)
    check(store.rows == 1)

    setComponent[Position](store, cPosition, idx, Position(x: 1, y: 2))
    setComponent[Label](store, cLabel, idx, Label(value: "foo"))

    check(store.column(cPosition).read(Position, idx) == Position(x: 1, y: 2))
    check(store.column(cLabel).read(Label, idx).value == "foo")
    check(store.entityId(idx) == EntityId(7))

    destroyColumn[Label](store, cLabel)

  test "Components the archetype does not have":
    var store = newStore(4, [colPosition])
    check(store.column(cLabel).isEmpty)
    check(store.column(cAbsent).isEmpty)
    check(not store.column(cPosition).isEmpty)
    check(NO_COLUMN.isEmpty)

  test "A reserved row starts zeroed":
    var store = newStore(4, [colPosition, colLabel])
    let idx = store.reserve(EntityId(1))

    # Nothing has been assigned into the row, but it still has to read as something
    check(store.column(cPosition).read(Position, idx) == Position(x: 0, y: 0))
    check(store.column(cLabel).read(Label, idx).value == "")

    destroyColumn[Label](store, cLabel)

  test "Reading a column points at the store itself":
    var store = newStore(4, [colPosition])
    let idx = store.reserve(EntityId(1))

    store.column(cPosition).at(Position, idx).x = 5
    check(store.column(cPosition).read(Position, idx).x == 5)

    check(
      store.column(cPosition).at(Position, idx) ==
        addr getColumn[Position](store, cPosition)[idx]
    )

  test "Rows are handed out in order":
    var store = newStore(4, [colPosition])
    check(store.reserve(EntityId(10)) == 0)
    check(store.reserve(EntityId(11)) == 1)
    check(store.reserve(EntityId(12)) == 2)
    check(store.len == 3)
    check(store.entityIds.toSeq == @[EntityId(10), EntityId(11), EntityId(12)])
    check(store.entities[1] == EntityId(11))

  test "Reserving more rows than an archetype has room for":
    var store = newStore(2, [colPosition])
    discard store.reserve(EntityId(1))
    discard store.reserve(EntityId(2))

    expect IndexDefect:
      discard store.reserve(EntityId(3))

    check(store.len == 2)

  test "Adding lengths onto a running total":
    var a = newStore(4, [colPosition])
    var b = newStore(4, [colPosition])
    discard a.reserve(EntityId(1))
    discard b.reserve(EntityId(2))
    discard b.reserve(EntityId(3))

    var total: Natural = 0
    a.addLen(total)
    b.addLen(total)
    check(total == 3)

  test "Columns stay aligned and do not overlap":
    const capacity = 7'u32
    # An odd capacity of a single byte component leaves the next column misaligned unless
    # something rounds it up
    var store = newStore(capacity, [colFlag, colWide, colPosition])

    check(cast[uint](pointer(store.column(cWide))) mod uint(alignof(Wide)) == 0)
    check(cast[uint](pointer(store.column(cPosition))) mod uint(alignof(Position)) == 0)

    for i in 0'u32 ..< capacity:
      check(store.reserve(EntityId(i)) == i)
      setComponent[Flag](store, cFlag, i, Flag(on: uint8(i + 1)))
      setComponent[Wide](store, cWide, i, Wide(value: int64(i) * 1000))
      setComponent[Position](store, cPosition, i, Position(x: int32(i), y: -int32(i)))

    for i in 0'u32 ..< capacity:
      check(store.column(cFlag).read(Flag, i).on == uint8(i + 1))
      check(store.column(cWide).read(Wide, i).value == int64(i) * 1000)
      check(
        store.column(cPosition).read(Position, i) == Position(x: int32(i), y: -int32(i))
      )
      check(store.entityId(i) == EntityId(i))

  test "Destroying a column destroys every live value in it":
    destroyed = @[]
    var store = newStore(8, [colTracked])
    for i in 1 .. 3:
      let idx = store.reserve(EntityId(i))
      setComponent[Tracked](store, cTracked, idx, Tracked(value: i))

    check(destroyed.len == 0)

    destroyColumn[Tracked](store, cTracked)
    check(destroyed == @[1, 2, 3])

  test "Dropping a row moves the last row down into the hole":
    destroyed = @[]
    var store = newStore(8, [colTracked])
    for i in 1 .. 3:
      let idx = store.reserve(EntityId(i * 10))
      setComponent[Tracked](store, cTracked, idx, Tracked(value: i))

    dropColumn[Tracked](store, cTracked, 1)

    # Only the dropped value is destroyed. The value that moves into its place is
    # relocated bitwise, so it is never destroyed at either end of the move
    check(destroyed == @[2])

    check(store.dropRow(1) == EntityId(30))
    check(store.len == 2)
    check(store.entityId(1) == EntityId(30))
    check(store.column(cTracked).read(Tracked, 0).value == 1)
    check(store.column(cTracked).read(Tracked, 1).value == 3)

    destroyColumn[Tracked](store, cTracked)
    check(destroyed == @[2, 1, 3])

  test "Dropping the last row moves nothing":
    destroyed = @[]
    var store = newStore(8, [colTracked])
    for i in 1 .. 3:
      let idx = store.reserve(EntityId(i * 10))
      setComponent[Tracked](store, cTracked, idx, Tracked(value: i))

    dropColumn[Tracked](store, cTracked, 2)
    check(destroyed == @[3])

    # There was nothing to move, so the entity that comes back is the deleted one
    check(store.dropRow(2) == EntityId(30))
    check(store.len == 2)
    check(store.entityIds.toSeq == @[EntityId(10), EntityId(20)])

    destroyColumn[Tracked](store, cTracked)
    check(destroyed == @[3, 1, 2])

  test "Dropping every row":
    var store = newStore(4, [colPosition])
    for i in 1 .. 3:
      discard store.reserve(EntityId(i))

    while store.len > 0:
      dropColumn[Position](store, cPosition, 0)
      discard store.dropRow(0)

    check(store.len == 0)
    check(store.entityIds.toSeq.len == 0)

  test "Tearing an archetype down leaves nothing behind":
    var store = newStore(4, [colPosition, colLabel])
    let idx = store.reserve(EntityId(1))
    setComponent[Label](store, cLabel, idx, Label(value: "foo"))

    destroyColumn[Label](store, cLabel)
    `=destroy`(store)

    check(store.len == 0)
    check(store.rows == 0)
    check(store.column(cPosition).isEmpty)
    check(store.column(cLabel).isEmpty)
    check(store.entityIds.toSeq.len == 0)

    # Tearing down what has already been torn down is not an error
    `=destroy`(store)
