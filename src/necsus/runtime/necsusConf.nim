import math

type
  NecsusLogger* = proc(message: string): void {.gcsafe, raises: [].}

  NecsusConf* = ref object ## Used to configure
    entitySize*: int
    componentSize*: int
    inboxSize*: int
    getTime*: proc(): BiggestFloat {.gcsafe.}
    log*: NecsusLogger
    eagerAlloc*: bool

proc logEcho(message: string) =
  when defined(necsusEchoLog):
    echo message

proc newNecsusConf*(
    getTime: proc(): BiggestFloat {.gcsafe.},
    log: NecsusLogger,
    entitySize: int,
    componentSize: int,
    inboxSize: int,
    eagerAlloc: bool = false,
): NecsusConf =
  ## Create a necsus configuration
  NecsusConf(
    entitySize: entitySize,
    componentSize: componentSize,
    inboxSize: inboxSize,
    getTime: getTime,
    log: log,
    eagerAlloc: eagerAlloc,
  )

proc newNecsusConf*(
    getTime: proc(): BiggestFloat {.gcsafe.},
    log: NecsusLogger,
    eagerAlloc: bool = false,
): NecsusConf =
  ## Create a necsus configuration
  NecsusConf(
    entitySize: 1_000,
    componentSize: 400,
    inboxSize: 50,
    getTime: getTime,
    log: log,
    eagerAlloc: eagerAlloc,
  )

when defined(js) or defined(osx) or defined(windows) or defined(posix):
  import std/times

  let DEFAULT_ENTITY_COUNT = 1_000

  var firstTime = epochTime()
  proc elapsedTime(): BiggestFloat =
    BiggestFloat(epochTime() - firstTime)

  proc newNecsusConf*(
      entitySize: int = DEFAULT_ENTITY_COUNT,
      componentSize: int = ceilDiv(entitySize, 3),
      inboxSize: int = max(entitySize div 20, 20),
      eagerAlloc: bool = false,
  ): NecsusConf =
    ## Create a necsus configuration
    newNecsusConf(
      elapsedTime, logEcho, entitySize, componentSize, inboxSize, eagerAlloc
    )
