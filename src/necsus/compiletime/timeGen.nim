import std/[macros, sets]
import common, systemGen, ../runtime/directives

let lastTime {.compileTime.} = ident("lastTime")

proc deltaFields(name: string): seq[WorldField] =
  @[(name, bindSym("TimeDelta")), (lastTime.strVal, bindSym("BiggestFloat"))]

proc generateDelta(details: GenerateContext, arg: SystemArg, name: string): NimNode =
  if isFastCompileMode(fastTime):
    return newEmptyNode()

  let timeDelta = name.ident
  let timeDeltaProc = details.globalName(name)
  case details.hook
  of Outside:
    let appType = details.appStateTypeName
    return quote:
      proc `timeDeltaProc`(
          `appStatePtr`: ptr `appType`
      ): BiggestFloat {.gcsafe, raises: [], nimcall, used.} =
        return `appStatePtr`.`thisTime` - `appStatePtr`.`lastTime`

  of Standard:
    return quote:
      `appStateIdent`.`timeDelta` = proc(): BiggestFloat =
        return `timeDeltaProc`(`appStatePtr`)
  of BeforeLoop:
    return quote:
      `appStateIdent`.`lastTime` = `appStateIdent`.`startTime`
  of LoopEnd:
    return quote:
      `appStateIdent`.`lastTime` = `appStateIdent`.`thisTime`
  else:
    return newEmptyNode()

let deltaGenerator* {.compileTime.} = newGenerator(
  ident = "TimeDelta",
  interest = {Standard, BeforeLoop, LoopEnd, Outside},
  generate = generateDelta,
  worldFields = deltaFields,
)

proc elapsedFields(name: string): seq[WorldField] =
  @[(name, bindSym("TimeElapsed"))]

proc generateElapsed(details: GenerateContext, arg: SystemArg, name: string): NimNode =
  if isFastCompileMode(fastTime):
    return newEmptyNode()

  let timeElapsed = name.ident
  let timeElapsedProc = details.globalName(name)
  case details.hook
  of Outside:
    let appType = details.appStateTypeName
    return quote:
      proc `timeElapsedProc`(
          `appStatePtr`: ptr `appType`
      ): BiggestFloat {.gcsafe, raises: [], nimcall, used.} =
        return `appStatePtr`.`thisTime` - `appStatePtr`.`startTime`

  of Standard:
    return quote:
      `appStateIdent`.`thisTime` = `appStateIdent`.`startTime`
      `appStateIdent`.`timeElapsed` = proc(): BiggestFloat =
        return `timeElapsedProc`(`appStatePtr`)
  else:
    return newEmptyNode()

let elapsedGenerator* {.compileTime.} = newGenerator(
  ident = "TimeElapsed",
  interest = {Standard, Outside},
  generate = generateElapsed,
  worldFields = elapsedFields,
)
