import unittest

import necsus

test "Creating query instances":
    let query = newQuery[(string, string)](
        proc (entityId: EntityId): auto =
        ("foo", "bar")
    )
