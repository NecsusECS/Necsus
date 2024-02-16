import necsus, bench, times

type
    Position {.byref.} = object
        x: float
        y: float

    Direction {.byref.} = object
        x: float
        y: float

    Comflabulation {.byref.} = object
        thingy: float
        dingy: int
        mingy: bool
        stringy: string

let entityCount = 1_000_000

proc setup(spawn: Spawn[(Comflabulation, Direction, Position)]) =
    spawn.with(Comflabulation(), Direction(), Position())
    benchmark "Creating " & $entityCount & " entities", entityCount:
        for i in 1..entityCount:
            spawn.with(Comflabulation(), Direction(), Position())

proc movement(dt: TimeDelta, entities: Query[tuple[pos: ptr Position, dir: Direction]]) =
    for comp in entities:
        comp.pos.x = comp.pos.x + (comp.dir.x * dt())
        comp.pos.y = comp.pos.y + (comp.dir.y * dt())

proc comflab(entities: Query[tuple[comflab: ptr Comflabulation]]) =
    for comp in entities:
        comp.comflab.thingy = comp.comflab.thingy * 1.000001f
        comp.comflab.mingy = not comp.comflab.mingy
        comp.comflab.dingy = comp.comflab.dingy + 1

proc runner(tick: proc(): void) =
    benchmark "Updating " & $entityCount & " components: https://github.com/abeimler/ecs_benchmark", entityCount:
        tick()

proc myApp() {.necsus(
    runner,
    [~setup, ~movement, ~comflab],
    newNecsusConf(entityCount * 2, entityCount * 2)
).}

myApp()
