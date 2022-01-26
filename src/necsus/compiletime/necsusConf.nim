import math

type
    NecsusConf* = object
        ## Used to configure
        entitySize*: int
        componentSize*: int

proc newNecsusConf*(
    entitySize: int = 1_000,
    componentSize: int = ceilDiv(entitySize, 3)
): NecsusConf =
    ## Create a necsus configuration
    NecsusConf(entitySize: entitySize, componentSize: componentSize)
