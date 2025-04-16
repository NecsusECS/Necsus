import unittest, necsus, options

proc setReturnValue(returnValue: Shared[string]) =
  returnValue.set("foobar")

proc runner(tick: proc(): void) =
  tick()

proc appReturnValue(): string {.necsus(runner, [~setReturnValue], newNecsusConf()).}

test "Use shared values for app return values":
  check(appReturnValue() == "foobar")

test "Fail if the return value isn't provided by a shared variable":
  when compiles(
    proc() =
      proc noAppReturnValue(): string {.necsus(runner, [], newNecsusConf()).}
  ):
    fail()

proc declaresReturnValue(returnValue: Shared[string]) =
  discard

proc unsetAppReturnValue(): string {.
  necsus(runner, [~declaresReturnValue], newNecsusConf())
.}

test "Throw if the return value is never set":
  expect UnpackDefect:
    discard unsetAppReturnValue()
