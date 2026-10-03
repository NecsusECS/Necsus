import necsus, std/[algorithm, sequtils, unittest, options]

type
  Direction = enum
    North
    East
    South
    West

  Name = string

  Facing = Option[Direction]
    ## An alias is the same type as what it names, so this is an optional `Direction`

  ChainedFacing = Facing

  Maybe[T] = Option[T]

  Unfaced = Not[Direction]

  WholeFacing = distinct Option[Direction]
    ## A distinct type is not an alias, so this is a component that holds a whole option

proc `==`(a, b: WholeFacing): bool {.borrow.}

proc setup(
    spawn: Spawn[(Name, Facing)],
    chained: Spawn[(Name, ChainedFacing)],
    generic: Spawn[(Name, Maybe[Direction])],
    whole: Spawn[(Name, WholeFacing)],
) =
  spawn.with("Jack", some(West))
  spawn.with("Jill", none(Direction))
  chained.with("John", some(North))
  generic.with("Jane", some(South))
  whole.with("Kim", WholeFacing(some(East)))

proc assertAliases(
    facing: Query[(Name, Facing)],
    chained: Query[(Name, ChainedFacing)],
    generic: Query[(Name, Maybe[Direction])],
    literal: Query[(Name, Option[Direction])],
) =
  let expected =
    @[
      ("Jack", some(West)),
      ("Jane", some(South)),
      ("Jill", none(Direction)),
      ("John", some(North)),
      ("Kim", none(Direction)),
    ]
  check(toSeq(facing.items).sortedByIt(it[0]) == expected)
  check(toSeq(chained.items).sortedByIt(it[0]) == expected)
  check(toSeq(generic.items).sortedByIt(it[0]) == expected)
  check(toSeq(literal.items).sortedByIt(it[0]) == expected)

proc assertComponents(
    withDirection: Query[(Name, Direction)],
    withoutDirection: Query[(Name, Unfaced)],
    whole: Query[(Name, WholeFacing)],
) =
  # Spawning through an alias attaches the component itself, not an option of it
  check(
    toSeq(withDirection.items).sortedByIt(it[0]) ==
      @[("Jack", West), ("Jane", South), ("John", North)]
  )
  check(toSeq(withoutDirection.items).mapIt(it[0]).sorted == @["Jill", "Kim"])
  check(toSeq(whole.items) == @[("Kim", WholeFacing(some(East)))])

proc assertLookup(
    spawn: FullSpawn[(Name, Facing)], lookup: Lookup[(Name, Maybe[Direction])]
) =
  let eid = spawn.with("Lee", some(East))
  check(lookup(eid) == some(("Lee", some(East))))

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.
  necsus(
    runner,
    [~setup, ~assertAliases, ~assertComponents, ~assertLookup],
    conf = newNecsusConf(),
  )
.}

test "An alias of an Option means the same as the Option it names":
  myApp()
