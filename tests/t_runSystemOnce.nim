import unittest, necsus, sequtils, bundle_include

runSystemOnce do (
    str: Shared[string],
    spawn: Spawn[(string, )],
    query: Query[(string, )],
    bundle: Bundle[Grouping],
) -> void:
    test "Execute a system defined via runSystemOnce":
        str := "foo"
        check(str.get == "foo")

        spawn.with("blah")
        check(query.toSeq == @[ ("blah", )])
