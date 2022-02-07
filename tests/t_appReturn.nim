import unittest, necsus, options

proc setReturnValue(returnValue: var Shared[string]) =
    returnValue.set("foobar")

proc runner(tick: proc(): void) = tick()

proc appReturnValue(): string {.necsus(runner, [], [~setReturnValue], [], newNecsusConf()).}

test "Use shared values for app return values":
    check(appReturnValue() == "foobar")

proc unsetAppReturnValue(): string {.necsus(runner, [], [], [], newNecsusConf()).}

test "Fail if the return value is unset":
    expect UnpackDefect:
        discard unsetAppReturnValue()
