import unittest, necsus

proc system(iterations: Local[int], exit: Shared[NecsusRun]) =
  if iterations.get(0) >= 10:
    exit := ExitLoop
  else:
    iterations := iterations.get(0) + 1

proc testDefaultGampeLoop() {.necsus(gameLoop, [~system], newNecsusConf()).}

test "Default game loop runner":
  testDefaultGampeLoop()
