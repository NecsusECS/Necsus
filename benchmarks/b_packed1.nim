import necsus, bench

type
    A = distinct int
    B = distinct int
    C = distinct int
    D = distinct int
    E = distinct int

proc setup(spawn: Spawn[(A, B, C, D, E)]) {.startupSys.} =
    for i in 1..1000:
        spawn.with(A(i), B(i), C(i), D(i), E(i))

proc modify(a: FullQuery[(A, )], attach: Attach[(A, )]) =
    for entity, comp in a:
        attach(entity, (A(int(comp[0]) * 2), ))

proc runner(tick: proc(): void) =
    benchmark "Packed iteration with 1 query and 1 system: https://github.com/noctjs/ecs-benchmark/", 1000:
        tick()

proc myApp() {.necsus(runner, [~setup, ~modify], newNecsusConf(10_000)).}

myApp()
