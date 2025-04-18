import necsus, bench

type
    A = distinct int
    B = distinct int
    C = distinct int
    D = distinct int
    E = distinct int
    F = distinct int
    G = distinct int
    H = distinct int
    I = distinct int
    J = distinct int
    K = distinct int
    L = distinct int
    M = distinct int

proc setup(
    spawn1: FullSpawn[(A, B, C)],
    spawn2: FullSpawn[(C, D, E)],
    spawn3: FullSpawn[(E, F, G)],
    spawn4: FullSpawn[(G, H, I)],
    attach1: Attach[(J, )],
    attach2: Attach[(K, )],
    attach3: Attach[(L, )],
    attach4: Attach[(M, )],
) {.startupSys.} =
    for i in 1..100:
        spawn1.with(A(i), B(i), C(i)).attach1((J(i), ))
        spawn2.with(C(i), D(i), E(i)).attach2((K(i), ))
        spawn3.with(E(i), F(i), G(i)).attach3((L(i), ))
        spawn4.with(G(i), H(i), I(i)).attach4((M(i), ))

var storage: int

proc query(
    j: FullQuery[(J, )],
    k: FullQuery[(K, )],
    l: FullQuery[(L, )],
    m: FullQuery[(M, )],
) =
    for entity, comp in j:
        storage = int(comp[0])
    for entity, comp in k:
        storage = int(comp[0])
    for entity, comp in l:
        storage = int(comp[0])
    for entity, comp in m:
        storage = int(comp[0])

proc runner(tick: proc(): void) =
    tick()
    benchmark "Archetype explosion", 1000:
        tick()

proc myApp() {.necsus(runner, [~setup, ~query], newNecsusConf(10_000, eagerAlloc = true)).}

myApp()

