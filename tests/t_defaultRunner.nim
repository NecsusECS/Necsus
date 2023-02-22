import unittest, necsus

proc system(iterations: Local[int], exit: Shared[NecsusRun]) =
    if iterations.get(0) >= 10:
        exit.set(ExitLoop)
    else:
        iterations.set(iterations.get(0) + 1)

proc testDefaultGampeLoop() {.necsus(gameLoop, [], [~system], [], newNecsusConf()).}

test "Default game loop runner":
    testDefaultGampeLoop()
