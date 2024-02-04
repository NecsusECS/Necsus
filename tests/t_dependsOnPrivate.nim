import unittest, necsus, privateSystem

proc runner(tick: proc(): void) = tick()

proc myApp() {.necsus(runner, [~assertion], newNecsusConf()).}

test "Depending on other systems with private visibility":
    myApp()
