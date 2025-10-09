import necsus, std/unittest

template exec() =
  runSystemOnce do() -> void:
    discard

exec()
exec()
exec()

test "Test runSystemOnce defined in a template":
  # Passes because it compiles
  discard
