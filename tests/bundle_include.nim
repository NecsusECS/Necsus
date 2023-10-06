import necsus, unittest, sequtils

type
    A* = object
    B* = object
    C* = object

    Grouping* = object
        create: Spawn[(A, B)]
        attach*: Attach[(C, )]

proc setup*(bundle: Bundle[Grouping]) =
    let eid = bundle.create.with(A(), B())
    bundle.attach(eid, (C(), ))

proc loop*(bundle: Bundle[Grouping], query: Query[(A, B, C)]) =
    setup(bundle)
    check(toSeq(query.items).len == 2)

proc teardown*(bundle: Bundle[Grouping], query: Query[(A, B, C)]) =
    setup(bundle)
    check(toSeq(query.items).len == 3)