import necsus, unittest

proc exit(exit: Shared[NecsusRun]) =
    exit.set(ExitLoop)

proc noRunner() {.necsus([~exit], newNecsusConf()).}

test "Instantiating without specifying runner":
    noRunner()
