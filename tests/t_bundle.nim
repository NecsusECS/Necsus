import unittest, necsus, bundle_include

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~setup], [~loop], [~teardown], conf = newNecsusConf()).}

test "Bundling directives into an object":
    myApp()

