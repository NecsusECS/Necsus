import necsus, bench, times, necsus/runtime/packedIntTable, necsus/runtime/queryFilter

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

proc exec(entityCount: int) =

    proc setup(spawn: Spawn[(Position, Direction, Comflabulation)]) =
        benchmark "Creating " & $entityCount & " entities", entityCount:
            for i in 1..entityCount:
                discard spawn((Position(), Direction(), Comflabulation()))

    proc movement(dt: TimeDelta, entities: Query[tuple[pos: Position, dir: Direction]], update: Update[(Position, )]) =
        for (e, comp) in entities:
            e.update((Position(x: comp.pos.x + (comp.dir.x * dt), y: comp.pos.y + (comp.dir.y * dt)), ))

    proc comflab(entities: Query[tuple[comflab: Comflabulation]], update: Update[(Comflabulation, )]) =
        for (e, comp) in entities:
            e.update((Comflabulation(
                thingy: comp.comflab.thingy * 1.000001f,
                mingy: not comp.comflab.mingy,
                dingy: comp.comflab.dingy + 1
            ), ))

    proc runner(tick: proc(): void) =
        benchmark "Updating " & $entityCount & " components: https://github.com/abeimler/ecs_benchmark", entityCount:
            tick()

    proc myApp() {.necsus(runner, [~setup], [~movement, ~comflab], initialSize = entityCount + 100).}

    myApp()

exec(1_000_000)
#exec(2_000_000)
#kexec(5_000_000)
