import unittest, necsus, sequtils

runSystemOnce do (str: Shared[string], spawn: Spawn[(string, )], query: Query[(string, )]) -> void:
    test "Execute a system defined via runSystemOnce":
        str := "foo"
        check(str.get == "foo")

        spawn.with("blah")
        check(query.toSeq == @[ ("blah", )])
