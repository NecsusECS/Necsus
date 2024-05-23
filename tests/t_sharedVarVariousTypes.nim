import unittest, necsus

proc create(
    sharedTuple: Shared[(float, bool)],
    sharedNamedTuple: Shared[tuple[num: float, truth: bool]],
    sharedSeq: Shared[seq[string]],
    sharedArray: Shared[array[5, char]],
) =
    sharedTuple.set((3.14, true))
    sharedNamedTuple.set((2.78, false))
    sharedSeq.set(@[ "a", "b", "c" ])
    sharedArray.set([ 'a', 'b', 'c', 'd', 'e' ])

proc assertions(
    sharedTuple: Shared[(float, bool)],
    sharedNamedTuple: Shared[tuple[num: float, truth: bool]],
    sharedSeq: Shared[seq[string]],
    sharedArray: Shared[array[5, char]],
) =
    check(sharedTuple.get == (3.14, true))
    check(sharedNamedTuple.get == (2.78, false))
    check(sharedSeq.get == @[ "a", "b", "c" ])
    check(sharedArray.get == [ 'a', 'b', 'c', 'd', 'e' ])

proc run(tick: proc(): void) =
    tick()

proc testSharedVar() {.necsus(run, [~create, ~assertions], newNecsusConf()).}

test "Creating shared vars with various types":
    testSharedVar()
