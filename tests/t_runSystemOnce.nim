import necsus, bundle_include, std/[options, sequtils, unittest]

runSystemOnce do(
  str: Shared[string],
  integer: Local[int],
  spawn: FullSpawn[(string,)],
  find: Lookup[(string,)],
  query: Query[(string, int)],
  add: Attach[(int,)],
  remove: Detach[(int,)],
  change: Swap[(float,), (string,)],
  bundle: Bundle[Grouping],
  send: Outbox[int],
  receive: Inbox[int],
  save: Save,
  restore: Restore,
  delete: Delete,
  deleteAll: DeleteAll[(string,)],
  delta: TimeDelta,
  elapsed: TimeElapsed,
  tickId: TickId
) -> void:
  test "Execute a system defined via runSystemOnce":
    str := "foo"
    check(str.get == "foo")

    let eid = spawn.with("blah")
    check(find(eid) == some(("blah",)))

    eid.add((123,))
    check(query.toSeq == @[("blah", 123)])
    eid.remove()
    check(query.len == 0)

    send(123)
    check(receive.toSeq == @[123])

    delete(eid)
    check(find(eid).isNone)

    spawn.with("blah").change((3.1415,))

    restore(save())

    deleteAll()

    check(delta() <= 0.0)
    check(elapsed() <= 0.0)

    integer := 1234
    check(integer == 1234)

    check(tickId() == 0)
