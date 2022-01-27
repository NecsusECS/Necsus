import necsus, bench

type
    A = distinct int
    B = distinct int
    C = distinct int
    D = distinct int
    E = distinct int

proc setup(spawn: Spawn[(A, B, C, D, E)]) =
    for i in 1..1000:
        discard spawn((A(i), B(i), C(i), D(i), E(i)))

proc modify(a: Query[(A, )], attach: Attach[(A, )]) =
    for (entity, comp) in a:
        attach(entity, (A(int(comp[0]) * 2), ))

proc runner(tick: proc(): void) =
    benchmark "Packed iteration with 1 query and 1 system", 1000:
        tick()

proc myApp() {.necsus(runner, [~setup], [~modify], conf = newNecsusConf(10_000)).}

myApp()
