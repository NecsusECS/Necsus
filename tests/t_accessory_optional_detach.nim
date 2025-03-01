import necsus, std/[sequtils, unittest, options]

type
    Person = object

    Name = string

    Age {.accessory.} = int

proc setup(
    spawnWithAge: FullSpawn[(Name, Person, Age)],
    spawnNoAge: FullSpawn[(Name, Person)],
    detach: Detach[(Option[Age], )]
) =
    spawnWithAge.with("Jack", Person(), 50).detach()
    spawnNoAge.with("Jill", Person()).detach()

proc assertion(noAge: Query[(Name, Not[Age])], aged: Query[(Age, )]) =
    check(noAge.mapIt(it[0]) == @["Jack", "Jill"])
    check(aged.len == 0)

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~setup, ~assertion], conf = newNecsusConf()).}

test "Optionally detaching an accessory component":
    myApp()