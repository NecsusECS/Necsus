## Port of the `BM_ComplexSystemsUpdate` case from https://github.com/abeimler/ecs_benchmark

import necsus, bench, std/random

type
  Position {.byref.} = object
    x: float32
    y: float32

  Velocity {.byref.} = object
    x: float32
    y: float32

  Data {.byref.} = object
    thingy: int32
    dingy: float64
    mingy: bool
    rng: Rand
    numgy: uint32

  PlayerType = enum
    NPC
    Monster
    Hero

  Player {.byref.} = object
    rng: Rand
    kind: PlayerType

  # `Spawning` is `Spawn` in the original. It is renamed here so it does not shadow the
  # `Spawn` directive, which this module also uses.
  StatusEffect = enum
    Spawning
    Dead
    Alive

  Health {.byref.} = object
    hp: int32
    maxhp: int32
    status: StatusEffect

  Damage {.byref.} = object
    atk: int32
    def: int32

  Sprite {.byref.} = object
    character: char

const
  DataSeed = 340383
  entityCount = 1_000_000
  frameWidth = 320
  frameHeight = 240
  spawnAreaMargin = 100

var frameBuffer: array[frameWidth * frameHeight, char]

proc randU32(rng: var Rand): uint32 {.inline.} =
  ## `rand(var Rand, typedesc)` only exists in Nim 2.0 and later, so pull the low bits off
  ## the raw stream, which is exactly what that overload does for a `uint32`
  uint32(rng.next and uint64(uint32.high))

proc draw(x, y: int, character: char) {.inline.} =
  if x in 0 ..< frameWidth and y in 0 ..< frameHeight:
    frameBuffer[x + y * frameWidth] = character

proc initStats(
    rng: var Rand, maxhp, def, atk: Slice[int]
): tuple[health: Health, damage: Damage] =
  ## Rolls the hp, defense and attack from the given ranges. Nim evaluates tuple and object
  ## fields left to right, so the rng is drawn from in the same order as the original.
  ## A range of `0 .. 0` costs no rng state, so it stands in for a flat zero.
  (
    Health(maxhp: int32(rng.rand(maxhp))),
    Damage(def: int32(rng.rand(def)), atk: int32(rng.rand(atk))),
  )

proc setup(
    spawn: Spawn[(Position, Velocity, Data, Player, Health, Damage, Sprite)]
) {.startupSys.} =
  # Every entity gets an identical `Data`, so build it once instead of re-seeding a PRNG a
  # million times. `initRand` is expensive -- it burns 128 rounds to jump the stream ahead.
  let baseData = block:
    var data = Data(rng: initRand(DataSeed))
    data.numgy = data.rng.randU32()
    data

  # A single stream for the setup rolls. The original seeds one PRNG per entity, but a
  # million short, sequentially seeded streams are both slower and worse mixed than one.
  var rng = initRand(DataSeed)

  for i in 0 ..< entityCount:
    var player = Player(rng: rng)

    let playerTypeRate = rng.rand(1 .. 100)
    player.kind =
      if playerTypeRate <= 3:
        NPC
      elif playerTypeRate <= 30:
        Hero
      else:
        Monster

    let (health, damage) =
      case player.kind
      of Hero:
        rng.initStats(maxhp = 5 .. 15, def = 2 .. 6, atk = 4 .. 10)
      of Monster:
        rng.initStats(maxhp = 4 .. 12, def = 2 .. 8, atk = 3 .. 9)
      of NPC:
        rng.initStats(maxhp = 6 .. 12, def = 3 .. 8, atk = 0 .. 0)

    let position = Position(
      x: float32(rng.rand(0 .. frameWidth + spawnAreaMargin) - spawnAreaMargin),
      y: float32(rng.rand(0 .. frameHeight + spawnAreaMargin) - spawnAreaMargin),
    )

    spawn.with(
      position,
      Velocity(x: 1, y: 1),
      baseData,
      player,
      health,
      damage,
      Sprite(character: '_'),
    )

proc movement(dt: TimeDelta, entities: Query[tuple[pos: ptr Position, vel: Velocity]]) =
  let delta = float32(dt())
  for comp in entities:
    comp.pos.x += comp.vel.x * delta
    comp.pos.y += comp.vel.y * delta

proc data(dt: TimeDelta, entities: Query[tuple[data: ptr Data]]) =
  let delta = dt()
  for comp in entities:
    comp.data.thingy = (comp.data.thingy + 1) mod 1_000_000
    comp.data.dingy += 0.0001 * delta
    comp.data.mingy = not comp.data.mingy
    comp.data.numgy = comp.data.rng.randU32()

proc moreComplex(
    entities: Query[tuple[pos: Position, vel: ptr Velocity, data: ptr Data]]
) =
  for comp in entities:
    if comp.data.thingy mod 10 == 0:
      if comp.pos.x > comp.pos.y:
        comp.vel.x = float32(comp.data.rng.rand(3 .. 19) - 10)
        comp.vel.y = float32(comp.data.rng.rand(0 .. 5))
      else:
        comp.vel.x = float32(comp.data.rng.rand(0 .. 5))
        comp.vel.y = float32(comp.data.rng.rand(3 .. 19) - 10)

proc health(entities: Query[tuple[health: ptr Health]]) =
  for comp in entities:
    let health = comp.health
    if health.hp <= 0 and health.status != Dead:
      health.hp = 0
      health.status = Dead
    elif health.status == Dead and health.hp == 0:
      health.hp = health.maxhp
      health.status = Spawning
    elif health.hp >= health.maxhp and health.status != Alive:
      health.hp = health.maxhp
      health.status = Alive
    else:
      health.status = Alive

proc damage(entities: Query[tuple[health: ptr Health, damage: Damage]]) =
  for comp in entities:
    let totalDamage = comp.damage.atk - comp.damage.def
    if comp.health.hp > 0 and totalDamage > 0:
      comp.health.hp = max(comp.health.hp - totalDamage, 0)

proc sprite(
    entities: Query[tuple[sprite: ptr Sprite, player: Player, health: Health]]
) =
  for comp in entities:
    comp.sprite.character =
      case comp.health.status
      of Alive:
        case comp.player.kind
        of Hero: '@'
        of Monster: 'k'
        of NPC: 'h'
      of Dead:
        '|'
      of Spawning:
        '_'

proc render(entities: Query[tuple[pos: Position, sprite: Sprite]]) =
  for comp in entities:
    draw(int(comp.pos.x), int(comp.pos.y), comp.sprite.character)

proc runner(tick: proc(): void) =
  tick()
  benchmarkLoop "Complex systems update over " & $entityCount &
    " entities: https://github.com/abeimler/ecs_benchmark", entityCount, 10:
    tick()

proc myApp() {.
  necsus(
    runner,
    [~setup, ~movement, ~data, ~moreComplex, ~health, ~damage, ~sprite, ~render],
    newNecsusConf(entityCount, entityCount, eagerAlloc = true),
  )
.}

myApp()
