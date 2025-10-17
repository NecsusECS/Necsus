import necsus, std/unittest

when (NIM_MAJOR, NIM_MINOR) >= (2, 3):
  type
    A = object
    B = object
    C = object
    D = object

    Control[T] = object
      spawn: Spawn[extend((A, B), T)]
      find: Query[extend((A, B), T)]

  proc create(ctrl: Bundle[Control[(C, D)]]) =
    ctrl.spawn.set(join((A(), B()) as (A, B), (C(), D()) as (C, D)))

  proc search(ctrl: Bundle[Control[(C, D)]]) =
    check(ctrl.find.len == 1)

  proc runner(tick: proc(): void) =
    tick()

  proc myApp() {.necsus(runner, [~create, ~search], newNecsusConf()).}

  test "Directive with extended tuples":
    myApp()
