import unittest, necsus

runSystemOnce do() -> void:
  test "Execute multiple systems in one file via runSystemOnce":
    discard

runSystemOnce do() -> void:
  discard
