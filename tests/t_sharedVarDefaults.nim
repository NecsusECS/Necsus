import unittest, necsus

type ExampleEnum = enum A, B, C

proc system(
    sharedInt: Shared[int],
    sharedFloat: Shared[float],
    sharedStr: Shared[string],
    sharedEnum: Shared[ExampleEnum],
    sharedSet: Shared[set[ExampleEnum]],
    sharedBool: Shared[bool],
    sharedSeq: Shared[seq[string]],
) =
    check(sharedInt.get == 0)
    check(sharedFloat.get == 0.0)
    check(sharedStr.get == "")
    check(sharedEnum.get == A)
    check(sharedSet.get == {})
    check(sharedBool.get == false)
    check(sharedSeq.get == newSeq[string]())

    check(sharedInt != 0)
    check(sharedFloat != 0.0)
    check(sharedStr != "")
    check(sharedEnum != A)
    check(sharedSet != {})
    check(sharedBool != false)
    check(sharedSeq != newSeq[string]())

proc runOnce(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runOnce, [], [~system], [], newNecsusConf()).}

test "Reading default values from shared values":
    myApp()

