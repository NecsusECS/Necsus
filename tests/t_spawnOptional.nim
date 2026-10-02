import necsus, std/[algorithm, sequtils, unittest, options]

type
  Direction = enum
    North
    East
    South
    West

  Name = string

  Title = string

  Age {.accessory.} = int

proc setup(
    spawn: Spawn[(Name, Option[Direction], Option[Title])],
    spawnAge: FullSpawn[(Name, Option[Age])],
) =
  spawn.with("Jack", some(West), some("Sir"))
  spawn.with("Jill", some(North), none(Title))
  spawn.with("John", none(Direction), some("Dr"))
  spawn.with("Jane", none(Direction), none(Title))
  discard spawnAge.with("Ann", some(30))
  discard spawnAge.with("Bob", none(Age))

proc assertOptional(all: Query[(Name, Option[Direction], Option[Title])]) =
  check(
    toSeq(all.items).filterIt(it[0] notin ["Ann", "Bob"]).sortedByIt(it[0]) ==
      @[
        ("Jack", some(West), some("Sir")),
        ("Jane", none(Direction), none(Title)),
        ("Jill", some(North), none(Title)),
        ("John", none(Direction), some("Dr")),
      ]
  )

proc assertArchetypes(
    both: Query[(Name, Direction, Title)],
    direction: Query[(Name, Direction, Not[Title])],
    title: Query[(Name, Not[Direction], Title)],
    neither: Query[(Name, Not[Direction], Not[Title])],
) =
  # Each combination of optional components lands in an archetype of its own
  check(toSeq(both.items).mapIt(it[0]) == @["Jack"])
  check(toSeq(direction.items).mapIt(it[0]) == @["Jill"])
  check(toSeq(title.items).mapIt(it[0]) == @["John"])
  check(toSeq(neither.items).mapIt(it[0]).sorted == @["Ann", "Bob", "Jane"])

proc assertAccessory(
    withAge: Query[(Name, Age)],
    withoutAge: Query[(Name, Not[Age], Not[Direction], Not[Title])],
    optionalAge: Query[(Name, Option[Age])],
) =
  check(toSeq(withAge.items) == @[("Ann", 30)])
  check(toSeq(withoutAge.items).mapIt(it[0]).sorted == @["Bob", "Jane"])
  check(
    toSeq(optionalAge.items).sortedByIt(it[0]).filterIt(it[0] in ["Ann", "Bob"]) ==
      @[("Ann", some(30)), ("Bob", none(Age))]
  )

proc assertLookup(
    spawn: FullSpawn[(Name, Option[Direction], Option[Title])],
    lookup: Lookup[(Name, Option[Direction], Option[Title])],
) =
  let withSome = spawn.with("Kim", some(South), none(Title))
  check(lookup(withSome) == some(("Kim", some(South), none(Title))))
  let withNone = spawn.with("Lee", none(Direction), some("Prof"))
  check(lookup(withNone) == some(("Lee", none(Direction), some("Prof"))))

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.
  necsus(
    runner,
    [~setup, ~assertOptional, ~assertArchetypes, ~assertAccessory, ~assertLookup],
    conf = newNecsusConf(),
  )
.}

test "Spawning with optional components":
  myApp()
