import math, directives

type
    NecsusConf* = ref object
        ## Used to configure
        entitySize*: int
        componentSize*: int
        getTime*: proc(): Nfloat
        log*: proc(message: string): void

proc logEcho(message: string) = echo message

proc newNecsusConf*(
    getTime: proc(): Nfloat,
    log: proc(message: string): void,
    entitySize: int,
    componentSize: int,
): NecsusConf =
    ## Create a necsus configuration
    NecsusConf(
        entitySize: entitySize,
        componentSize: componentSize,
        getTime: getTime,
        log: log,
    )

proc newNecsusConf*(getTime: proc(): Nfloat, log: proc(message: string): void): NecsusConf =
    ## Create a necsus configuration
    NecsusConf(entitySize: 1_000, componentSize: 400, getTime: getTime, log: log)

when defined(js) or defined(osx) or defined(windows) or defined(posix):
    import std/times

    let DEFAULT_ENTITY_COUNT = 1_000

    var firstTime = epochTime()
    proc elapsedTime(): NFloat = NFloat(epochTime() - firstTime)

    proc newNecsusConf*(
        entitySize: int = DEFAULT_ENTITY_COUNT,
        componentSize: int = ceilDiv(entitySize, 3),
    ): NecsusConf =
        ## Create a necsus configuration
        newNecsusConf(elapsedTime, logEcho, entitySize, componentSize)
