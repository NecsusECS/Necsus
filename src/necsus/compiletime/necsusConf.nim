import math

type
    NecsusConf* = object
        ## Used to configure
        entitySize*: int
        componentSize*: int
        eventQueueSize*: int

proc newNecsusConf*(
    entitySize: int = 1_000,
    componentSize: int = ceilDiv(entitySize, 3),
    eventQueueSize: int = ceilDiv(entitySize, 10)
): NecsusConf =
    ## Create a necsus configuration
    NecsusConf(entitySize: entitySize, componentSize: componentSize, eventQueueSize: eventQueueSize)
