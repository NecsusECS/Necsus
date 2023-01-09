# import unittest, necsus, sequtils
#
# type
#     A = object
#     B = object
#     C = object
#     D = object
#     E = object
#
# proc setup(spawn: Spawn[(A, B, C, D)]) =
#     discard spawn((A(), B(), C(), D()))
#
# proc detacher(query: Query[(A, )], detach: Detach[(C, D, E)]) =
#     for entityId, _ in query:
#         detach(entityId)
#
# proc assertions(
#     findA: Query[(A, )],
#     findB: Query[(B, )],
#     findC: Query[(C, )],
#     findD: Query[(D, )],
#     findE: Query[(E, )]
# ) =
#     check(findA.items.toSeq().len == 1)
#     check(findB.items.toSeq().len == 1)
#     check(findC.items.toSeq().len == 0)
#     check(findD.items.toSeq().len == 0)
#     check(findE.items.toSeq().len == 0)
#
# proc runner(tick: proc(): void) = tick()
#
# proc myApp() {.necsus(runner, [~setup], [~detacher, ~assertions], [], newNecsusConf()).}
#
# test "Detaching should participate in component group determination":
#     myApp()
