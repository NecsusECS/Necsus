import unittest, necsus

type SystemInst = object
    value: string

var execStatus = "Status:"

proc initSystem(): SystemInst {.instanced.} =
    result.value = "foo"
    execStatus &= " init"

proc tick(obj: var SystemInst) =
    check(obj.value == "foo")
    obj.value = "bar"
    execStatus &= " tick"

{.warning[Deprecated]:off.}
proc `=destroy`(obj: var SystemInst) {.raises: [Exception].} =
    # When the object is first created, it destroys the place holder. So we need to handle both
    check(obj.value in ["", "bar"])
    execStatus &= " destroy"

proc runner(tick: proc(): void) =
    tick()

proc myApp() {.necsus(runner, [~initSystem], newNecsusConf()).}

test "Executed instanced systems that return objects":
    myApp()
    check(execStatus == "Status: init destroy tick destroy")

