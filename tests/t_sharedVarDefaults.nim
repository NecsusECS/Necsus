import unittest, necsus, options

type
    ExampleEnum = enum A, B, C

    ExampleObj = object
        key: int

proc system(
    sharedInt: Shared[int],
    sharedFloat: Shared[float],
    sharedStr: Shared[string],
    sharedEnum: Shared[ExampleEnum],
    sharedSet: Shared[set[ExampleEnum]],
    sharedBool: Shared[bool],
    sharedSeq: Shared[seq[string]],
    sharedObj: Shared[ExampleObj],
    sharedRef: Shared[ref ExampleObj],
) =
    check(sharedInt.get == 0)
    check(sharedFloat.get == 0.0)
    check(sharedStr.get == "")
    check(sharedEnum.get == A)
    check(sharedSet.get == {})
    check(sharedBool.get == false)
    check(sharedSeq.get == newSeq[string]())
    check(sharedObj.get.key == 0)

    expect UnpackDefect:
        discard sharedRef.get

proc runOnce(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runOnce, [~system], newNecsusConf()).}

test "Reading default values from shared values":
    myApp()

