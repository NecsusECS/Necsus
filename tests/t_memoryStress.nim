## Randomized churn against the memory guarantees of the archetype store.
##
## Every component carries a heap allocation and a destructor that counts itself, so a
## value that goes missing, is destroyed twice, or is left behind by an archetype move
## shows up as a count that stops matching the model rather than as a leak nobody notices.

import necsus
import std/[unittest, random, options, sequtils, algorithm, strutils]

const
  # Ticks of random operations per run. A trace prints a line per operation and the point
  # of a trace is to be readable, so those builds settle for a lot less churn
  stressTicks {.intdefine.} =
    when defined(necsusEntityTrace) or defined(necsusQueryTrace) or
        defined(necsusSystemTrace): 30 else: 300

  stressOpsPerTick {.intdefine.} = 10

  stressMaxEntities {.intdefine.} = 120
    ## How many entities to allow before operations start deleting instead of spawning.
    ## Every archetype is given room for exactly this many rows, which is the most that
    ## could ever end up in one of them, so the churn runs against a full archetype rather
    ## than in the middle of one

  fillRows {.intdefine.} = 64
    ## How many rows the archetype in the boundary test holds. Filling one to its last row
    ## is what puts the column layout under any pressure at all -- an archetype with room
    ## to spare never reaches the end of a column, so columns that overlap still read
    ## correctly

  memoryTolerance = 32 * 1024
    ## How much memory a whole run is allowed to leave behind. A leak of a single component
    ## per operation would be several times this

type
  Op = enum
    ## An operation the churn picks between. Every one of these has to be reached, which is
    ## checked after the run
    opSpawnBare
    opSpawnHealth
    opSpawnEverything
    opDelete
    opAttachHealth
    opAttachShield
    opAttachPoison
    opDetachHealth
    opDetachShield
    opDetachPoison
    opSwapShieldForHealth
    opSwapHealthForShield

  Tracked = object
    ## A component payload that can tell whether it was destroyed exactly once. The heap
    ## allocation is what makes a leak measurable, and the id is what makes a value
    ## identifiable again after a row has been shuffled around
    id: int
    payload: string

  Name = object
    val: Tracked

  Health = object
    val: Tracked

  Shield = object
    val: Tracked

  Poison {.accessory.} = object
    val: Tracked

  Level = object ## A component with no hooks, so a query still walks the plain path
    depth: int

  Flag = object
    ## A single byte, so the column after it only lines up if the layout rounds an offset
    ## up to the alignment its component asked for
    on: bool

  Expected = object ## What an entity is supposed to be holding. An id of zero is absent
    eid: EntityId
    name, level, health, shield, poison: int

  Model = ref object
    rand: Rand
    live: seq[Expected]
    idSeq: int

var liveValues = 0 ## Tracked values in existence right now
var totalCreated = 0
var badDestroys = 0 ## Destroys of a value that was never created, or was corrupted
var performed: array[Op, int]

func payloadLen(id: int): int =
  24 + (id mod 16)

func payloadChar(id: int): char =
  char(ord('a') + (id mod 26))

template isIntact(tracked: Tracked): bool =
  ## Whether a value still reads as the one it was created as. Both ends of the payload
  ## are checked, so a value overwritten by a neighbouring row is noticed.
  ##
  ## A template because the hooks below have to be the first thing that touches this type
  tracked.payload.len == payloadLen(tracked.id) and
    tracked.payload[0] == payloadChar(tracked.id) and
    tracked.payload[^1] == payloadChar(tracked.id)

{.warning[Deprecated]: off.}

proc `=destroy`(tracked: var Tracked) =
  if tracked.id != 0:
    if not tracked.isIntact:
      badDestroys += 1
    liveValues -= 1
  elif tracked.payload.len != 0:
    # A vacated row reads as zero, and a zeroed value has to survive being destroyed
    badDestroys += 1
  `=destroy`(tracked.payload)

proc `=copy`(dest: var Tracked, src: Tracked) =
  ## Copies are counted like anything else, so an extra copy that never gets destroyed is
  ## as visible as a value that was dropped
  `=destroy`(dest)
  wasMoved(dest)
  dest.id = src.id
  dest.payload = src.payload
  if src.id != 0:
    liveValues += 1
    totalCreated += 1

proc newTracked(id: int): Tracked =
  liveValues += 1
  totalCreated += 1
  Tracked(id: id, payload: payloadChar(id).repeat(payloadLen(id)))

proc nextValue(model: Model): int =
  model.idSeq += 1
  model.idSeq

proc trackedValues(model: Model): int =
  ## How many tracked values every live entity adds up to
  for entity in model.live:
    for id in [entity.name, entity.health, entity.shield, entity.poison]:
      if id != 0:
        result += 1

proc setup(model: Shared[Model]) {.startupSys.} =
  model := Model(rand: initRand(0x5eed))

proc churn(
    model: Shared[Model],
    spawnBare: FullSpawn[(Name, Level)],
    spawnHealth: FullSpawn[(Name, Level, Health)],
    spawnEverything: FullSpawn[(Name, Level, Health, Shield, Poison)],
    delete: Delete,
    attachHealth: Attach[(Health,)],
    attachShield: Attach[(Shield,)],
    attachPoison: Attach[(Poison,)],
    detachHealth: Detach[(Health,)],
    detachShield: Detach[(Shield,)],
    detachPoison: Detach[(Poison,)],
    shieldForHealth: Swap[(Shield,), (Health,)],
    healthForShield: Swap[(Health,), (Shield,)],
) {.loopSys.} =
  ## Applies random operations, keeping a model of what every entity should be holding.
  ##
  ## Nothing here touches an entity while a query is being walked -- the entities come out
  ## of the model rather than out of an iteration, so this stays clear of the one thing a
  ## packed archetype cannot promise
  let m = model.get

  for _ in 1 .. stressOpsPerTick:
    var op = Op(m.rand.rand(ord(Op.high)))

    if m.live.len == 0:
      op = opSpawnBare
    elif m.live.len >= stressMaxEntities and
        op in {opSpawnBare, opSpawnHealth, opSpawnEverything}:
      op = opDelete

    performed[op] += 1

    let idx =
      if m.live.len == 0:
        0
      else:
        m.rand.rand(m.live.len - 1)

    case op
    of opSpawnBare:
      var entity = Expected(name: m.nextValue, level: m.nextValue)
      entity.eid =
        spawnBare.with(Name(val: newTracked(entity.name)), Level(depth: entity.level))
      m.live.add(entity)
    of opSpawnHealth:
      var entity = Expected(name: m.nextValue, level: m.nextValue, health: m.nextValue)
      entity.eid = spawnHealth.with(
        Name(val: newTracked(entity.name)),
        Level(depth: entity.level),
        Health(val: newTracked(entity.health)),
      )
      m.live.add(entity)
    of opSpawnEverything:
      var entity = Expected(
        name: m.nextValue,
        level: m.nextValue,
        health: m.nextValue,
        shield: m.nextValue,
        poison: m.nextValue,
      )
      entity.eid = spawnEverything.with(
        Name(val: newTracked(entity.name)),
        Level(depth: entity.level),
        Health(val: newTracked(entity.health)),
        Shield(val: newTracked(entity.shield)),
        Poison(val: newTracked(entity.poison)),
      )
      m.live.add(entity)
    of opDelete:
      delete(m.live[idx].eid)
      m.live.del(idx)
    of opAttachHealth:
      # Attaching something an entity already has overwrites it, which is a different
      # path through the generated code than one that moves the entity to a new archetype
      let id = m.nextValue
      m.live[idx].eid.attachHealth((Health(val: newTracked(id)),))
      m.live[idx].health = id
    of opAttachShield:
      let id = m.nextValue
      m.live[idx].eid.attachShield((Shield(val: newTracked(id)),))
      m.live[idx].shield = id
    of opAttachPoison:
      let id = m.nextValue
      m.live[idx].eid.attachPoison((Poison(val: newTracked(id)),))
      m.live[idx].poison = id
    of opDetachHealth:
      # A detach of something that is not there does nothing, and the model already says
      # so, which is what makes the no-op worth issuing
      m.live[idx].eid.detachHealth()
      m.live[idx].health = 0
    of opDetachShield:
      m.live[idx].eid.detachShield()
      m.live[idx].shield = 0
    of opDetachPoison:
      m.live[idx].eid.detachPoison()
      m.live[idx].poison = 0
    of opSwapShieldForHealth:
      # A swap only happens when everything it would detach is present. When it is not,
      # the components it was handed still have to be disposed of by the swap itself
      let id = m.nextValue
      m.live[idx].eid.shieldForHealth((Shield(val: newTracked(id)),))
      if m.live[idx].health != 0:
        m.live[idx].shield = id
        m.live[idx].health = 0
    of opSwapHealthForShield:
      let id = m.nextValue
      m.live[idx].eid.healthForShield((Health(val: newTracked(id)),))
      if m.live[idx].shield != 0:
        m.live[idx].health = id
        m.live[idx].shield = 0

proc verify(
    model: Shared[Model],
    lookup: Lookup[
      (ptr Name, ptr Level, Option[ptr Health], Option[ptr Shield], Option[ptr Poison])
    ],
    everyone: FullQuery[(ptr Name,)],
    healthy: Query[(ptr Health,)],
    shielded: Query[(ptr Shield,)],
    poisoned: Query[(ptr Poison,)],
    unpoisoned: Query[(ptr Name, Not[Poison])],
    levels: Query[(Level,)],
) {.loopSys.} =
  ## Checks the world against the model. This runs before anything else has a chance to
  ## make a copy, so the number of values in existence has to be exactly the number the
  ## model accounts for
  let m = model.get

  check(liveValues == m.trackedValues)
  check(badDestroys == 0)

  check(everyone.len == m.live.len)
  check(levels.len == m.live.len)
  check(healthy.len == m.live.countIt(it.health != 0))
  check(shielded.len == m.live.countIt(it.shield != 0))
  check(poisoned.len == m.live.countIt(it.poison != 0))
  check(unpoisoned.len == m.live.countIt(it.poison == 0))

  var found: seq[uint]
  for eid, _ in everyone:
    found.add(uint(eid))
  check(found.sorted == m.live.mapIt(uint(it.eid)).sorted)

  for entity in m.live:
    let comps = lookup(entity.eid)
    check(comps.isSome)
    if comps.isSome:
      let (name, level, health, shield, poison) = comps.get
      check(name.val.id == entity.name)
      check(name.val.isIntact)
      check(level.depth == entity.level)
      check(health.isSome == (entity.health != 0))
      check(shield.isSome == (entity.shield != 0))
      check(poison.isSome == (entity.poison != 0))
      if health.isSome:
        check(health.get.val.id == entity.health)
        check(health.get.val.isIntact)
      if shield.isSome:
        check(shield.get.val.id == entity.shield)
        check(shield.get.val.isIntact)
      if poison.isSome:
        check(poison.get.val.id == entity.poison)
        check(poison.get.val.isIntact)

proc runner(tick: proc(): void) =
  for _ in 1 .. stressTicks:
    tick()

proc stressApp() {.
  necsus(
    runner,
    [~setup, ~churn, ~verify],
    newNecsusConf(entitySize = stressMaxEntities * 2, componentSize = stressMaxEntities),
  )
.}

proc fillUp(
    spawn: FullSpawn[(Flag, Health, Level, Name, Poison, Shield)],
    live: Shared[seq[EntityId]],
) {.startupSys.} =
  ## Fills an archetype right up to its last row
  var spawned: seq[EntityId]
  for i in 1 .. fillRows:
    let base = i * 8
    spawned.add spawn.with(
      Flag(on: i mod 2 == 0),
      Health(val: newTracked(base + 1)),
      Level(depth: base + 2),
      Name(val: newTracked(base + 3)),
      Poison(val: newTracked(base + 4)),
      Shield(val: newTracked(base + 5)),
    )
  live := spawned

proc checkFilled(
    live: Shared[seq[EntityId]],
    lookup: Lookup[(ptr Flag, ptr Health, ptr Level, ptr Name, ptr Poison, ptr Shield)],
    everyone: Query[(ptr Name,)],
) {.loopSys.} =
  ## Reads every row back. A column laid out over the top of the one after it only shows
  ## up once the rows reach that far, which is what filling the archetype is for
  check(everyone.len == fillRows)
  check(live.get.len == fillRows)

  for i, eid in live.get:
    let found = lookup(eid)
    check(found.isSome)
    if found.isSome:
      let (flag, health, level, name, poison, shield) = found.get
      let base = (i + 1) * 8
      check(flag.on == ((i + 1) mod 2 == 0))
      check(level.depth == base + 2)
      for (tracked, id) in [
        (health.val, base + 1),
        (name.val, base + 3),
        (poison.val, base + 4),
        (shield.val, base + 5),
      ]:
        check(tracked.id == id)
        check(tracked.isIntact)

proc emptyOut(everyone: FullQuery[(ptr Name,)], delete: Delete) {.teardownSys.} =
  ## Deletes the rows the ordinary way, so teardown is not the only thing that ever gets
  ## to destroy a full archetype
  for eid, _ in everyone:
    delete(eid)

proc fillRunner(tick: proc(): void) =
  tick()

proc fillApp() {.
  necsus(
    fillRunner,
    [~fillUp, ~checkFilled, ~emptyOut],
    newNecsusConf(entitySize = fillRows * 2, componentSize = fillRows),
  )
.}

suite "Memory guarantees under random churn":
  test "Values are all accounted for once the app is gone":
    stressApp()
    check(liveValues == 0)
    check(badDestroys == 0)
    check(totalCreated > stressTicks)

  test "A run gives back everything it took":
    # The first run warms up whatever the allocator and the test framework hold on to, so
    # it is the second one whose memory has to come back
    GC_fullCollect()
    let baseline = getOccupiedMem()

    stressApp()

    check(liveValues == 0)
    check(badDestroys == 0)

    GC_fullCollect()
    check(getOccupiedMem() - baseline <= memoryTolerance)

  test "An archetype filled to its last row":
    GC_fullCollect()
    let baseline = getOccupiedMem()

    fillApp()

    check(liveValues == 0)
    check(badDestroys == 0)

    GC_fullCollect()
    check(getOccupiedMem() - baseline <= memoryTolerance)

  test "Every operation was reached":
    for op, count in performed:
      checkpoint($op & " ran " & $count & " times")
      check(count > 0)
