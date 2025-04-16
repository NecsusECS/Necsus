import necsus, std/[options, unittest]

type
  Thingy = object
  Other = object
  Whatsit = object

proc assertions(
    spawn: FullSpawn[(Thingy, Other)],
    find: Lookup[(Thingy,)],
    delete: Delete,
    findAgain: Query[(Thingy, Not[Whatsit])],
    debug: EntityDebug,
    attach: Attach[(Whatsit,)],
    detach: Detach[(Thingy,)],
    swap: Swap[(Whatsit,), (Thingy,)],
) =
  var eid = spawn.with(Thingy(), Other())

  check(find(eid.incGen).isNone)

  delete(eid.incGen)
  check(findAgain.len == 1)

  check(debug(eid.incGen) == "No such entity: EntityId(1:0)")

  attach(eid.incGen, (Whatsit(),))
  check(findAgain.len == 1)

  detach(eid.incGen)
  check(findAgain.len == 1)

  swap(eid.incGen, (Whatsit(),))
  check(findAgain.len == 1)

proc runner(tick: proc(): void) =
  tick()

proc myApp() {.necsus(runner, [~assertions], newNecsusConf()).}

test "Missing entityIDs should not cause failures":
  myApp()
