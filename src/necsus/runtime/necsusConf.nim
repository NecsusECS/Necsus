import math

type
    NecsusConf* = object
        ## Used to configure
        entitySize*: int
        componentSize*: int
        eventQueueSize*: int
        getTime*: proc(): float

proc newNecsusConf*(
    getTime: proc(): float,
    entitySize: int = 1_000,
    componentSize: int = ceilDiv(entitySize, 3),
    eventQueueSize: int = ceilDiv(entitySize, 10),
): NecsusConf =
    ## Create a necsus configuration
    NecsusConf(
        entitySize: entitySize,
        componentSize: componentSize,
        eventQueueSize: eventQueueSize,
        getTime: getTime
    )

when defined(js) or defined(osx) or defined(windows) or defined(posix):
    import std/times

    proc newNecsusConf*(
        entitySize: int = 1_000,
        componentSize: int = ceilDiv(entitySize, 3),
        eventQueueSize: int = ceilDiv(entitySize, 10)
    ): NecsusConf =
        ## Create a necsus configuration
        newNecsusConf(epochTime, entitySize, componentSize, eventQueueSize)
