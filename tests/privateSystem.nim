import necsus, unittest, sequtils

proc creator(spawn: Spawn[(string, )]) =
    discard spawn.with("foo")

proc assertion*(query: Query[(string,)]) {.depends(creator).} =
    check(query.toSeq == @[("foo", )])