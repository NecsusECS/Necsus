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

template setupSystem(typ: typedesc) =
    proc `modify typ`(query: Query[(typ, )], update: Update[(typ, )]) =
        for (entity, comp) in query.pairs:
            update(entity, (typ(int(comp[0]) * 2), ))

setupSystem(A)
setupSystem(B)
setupSystem(C)
setupSystem(D)
setupSystem(E)

proc runner(tick: proc(): void) =
    benchmark "Packed iteration with 1 query", 5000:
        tick()

proc myApp() {.necsus(runner, [~setup], [~modifyA, ~modifyB, ~modifyC, ~modifyD, ~modifyE], initialSize = 10_000).}

myApp()
